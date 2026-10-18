-- SimpleBlessingBar - the bar
-- Handle, position and lock; one secure button per class in the group. Targets, ranks and
-- counts come from Blessings.lua out of combat; in combat nothing is rewritten and the
-- buttons keep what they had (ruleset plan 2026-10-18-class-blessing-bar).

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings
local SetAttr = ns.SetAttr

local SIZE, GAP, PAD = D.SIZE, D.GAP, D.PAD
-- The aura and Righteous Fury buttons (SelfBuffs.lua) take the first two places
local FIRST_CLASS_X = PAD + 2 * (SIZE + GAP)
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local db
ns.OnDBReady(function(d) db = d end)

---------------------------------------------------------------------------
-- Look shared by the bar and the flyouts: SimpleConjureBar's
---------------------------------------------------------------------------
function ns.ApplyBackdrop(frame)
    frame:SetBackdrop(D.BACKDROP)
    local c, e = D.BG_COLOR, D.BORDER_COLOR
    frame:SetBackdropColor(c.r, c.g, c.b, c.a)
    frame:SetBackdropBorderColor(e.r, e.g, e.b, e.a)
end

-- A secure button with its own action button look, as in SimpleConjureBar. Deliberately
-- without ActionButtonTemplate: its scripts override a secure button's click handling.
function ns.CreateSecureButton(name, parent)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)

    -- Pixel-exact symmetric border: dark background, icon inset by 1 px
    local edge = b:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(0, 0, 0, 1)

    b.icon = b:CreateTexture(nil, "BORDER")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Pushed and hover textures exactly on the icon
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    local pushed = b:GetPushedTexture()
    pushed:ClearAllPoints()
    pushed:SetAllPoints(b.icon)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local hl = b:GetHighlightTexture()
    hl:ClearAllPoints()
    hl:SetAllPoints(b.icon)

    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)

    -- A secure click acts on key down or up per ActionButtonUseKeyDown; both are registered
    b:RegisterForClicks("AnyUp", "AnyDown")
    return b
end

-- The spell a main button casts, as the game's own tooltip
function ns.ShowSpellTooltip(self)
    local spell = self:GetAttribute("spell1")
    if not spell then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetSpellByID(spell)
    GameTooltip:Show()
end

function ns.HideTooltip()
    GameTooltip:Hide()
end

---------------------------------------------------------------------------
-- Bar and handle
---------------------------------------------------------------------------
local bar = CreateFrame("Frame", "SimpleBlessingBarFrame", UIParent, "BackdropTemplate")
ns.bar = bar
bar:SetSize(SIZE + 2 * PAD, SIZE + 2 * PAD)
bar:SetMovable(true)
bar:SetClampedToScreen(true)
bar:SetPoint("CENTER", UIParent, "CENTER", 0, -150) -- start position, replaced at login
ns.ApplyBackdrop(bar)

-- Drag handle; only visible while the mouse is over it, or while dragging
local handle = CreateFrame("Frame", nil, bar)
ns.handle = handle
handle:SetSize(10, SIZE)
handle:SetPoint("RIGHT", bar, "LEFT", -1, 0)
handle:EnableMouse(true)
handle:SetAlpha(0)
local handleTex = handle:CreateTexture(nil, "BACKGROUND")
handleTex:SetAllPoints()
handle:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
handle:SetScript("OnLeave", function(self) if not self.moving then self:SetAlpha(0) end end)

function ns.LoadPosition()
    bar:ClearAllPoints()
    bar:SetPoint(db.point or "CENTER", UIParent, db.rel or "CENTER", db.x or 0, db.y or -150)
end

-- Anchors the bar at its left edge without moving it on screen, and saves the position
local function SavePosition()
    local l, b, _, h = bar:GetRect()
    if not l then return end
    bar:ClearAllPoints()
    bar:SetPoint("LEFT", UIParent, "BOTTOMLEFT", l, b + h / 2)
    db.point, db.rel, db.x, db.y = "LEFT", "BOTTOMLEFT", l, b + h / 2
end

-- Locked = red, unlocked = blue
function ns.ApplyLock()
    local c = db.locked and D.HANDLE_LOCKED or D.HANDLE_UNLOCKED
    handleTex:SetColorTexture(c.r, c.g, c.b, c.a)
end

function ns.ToggleLock()
    db.locked = not db.locked
    ns.ApplyLock()
end

-- The bar holds secure buttons, so it is protected in combat: it cannot move then.
handle:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        if InCombatLockdown() then
            ns.Print(L.NOT_IN_COMBAT)
        elseif not db.locked then
            self.moving = true
            bar:StartMoving()
        end
    elseif button == "RightButton" then
        ns.ToggleLock()
    end
end)

-- StopMovingOrSizing must not be called once the lockdown is active.
local function StopDrag()
    if not handle.moving then return end
    handle.moving = false
    if InCombatLockdown() then return end
    bar:StopMovingOrSizing()
    SavePosition()
    if not handle:IsMouseOver() then handle:SetAlpha(0) end
end
handle:SetScript("OnMouseUp", StopDrag)

---------------------------------------------------------------------------
-- Class buttons
---------------------------------------------------------------------------
local buttons = {}
ns.classButtons = buttons

-- The class is the button's icon; the assigned blessing sits small in the top right corner,
-- the count bottom right where SimpleConjureBar keeps its counts.
for _, class in ipairs(D.CLASS_ORDER) do
    local b = ns.CreateSecureButton("SimpleBlessingBarClass" .. class, bar)
    b.classIcon = b.icon
    b.classIcon:SetTexture(CLASS_ICONS)
    b.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
    b.blessIcon = b:CreateTexture(nil, "ARTWORK")
    b.blessIcon:SetSize(SIZE / 2 - 2, SIZE / 2 - 2)
    b.blessIcon:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1)
    b.blessIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetScript("OnEnter", ns.ShowSpellTooltip)
    b:SetScript("OnLeave", ns.HideTooltip)
    b.class = class
    b:Hide()
    buttons[class] = b
end

-- Left click only: right click stays free for the assignment menu
local function SetAction(b, spell, unit)
    SetAttr(b, "type1", spell and "spell" or nil)
    SetAttr(b, "spell1", spell)
    SetAttr(b, "unit1", spell and unit or nil)
end

local function Update(b, family)
    local state = family and B.ClassState(b.class, family) or { castable = false, count = 0 }
    if state.castable and state.target then
        SetAction(b, state.spell, state.target)
    else
        SetAction(b, nil)
    end
    local icon = family and (state.spell or D.BLESSINGS[family].normal[1])
    b.blessIcon:SetTexture(icon and C_Spell.GetSpellTexture(icon) or nil)
    b.classIcon:SetDesaturated(not state.castable)
    b.blessIcon:SetDesaturated(not state.castable)
    b.count:SetText(state.castable and tostring(state.count) or "")
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
-- Other buttons on the bar refresh with it: functions added here run after the class
-- buttons, out of combat only.
ns.onRefresh = {}

-- Reads the group out of combat and writes everything to the buttons. In combat it does
-- nothing: aura data is unreadable then and the buttons are protected.
-- PLAYER_REGEN_ENABLED runs it again, which also applies anything ns.SetAttr skipped.
function ns.Refresh()
    if not db or InCombatLockdown() then return end
    ns.attrPending = false

    local present = {}
    for _, unit in ipairs(B.Members()) do
        local class = select(2, UnitClass(unit))
        if class then present[class] = true end
    end
    local x = FIRST_CLASS_X
    for _, class in ipairs(D.CLASS_ORDER) do
        local b = buttons[class]
        if present[class] then
            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "LEFT", x, 0)
            x = x + SIZE + GAP
            b:Show()
            Update(b, db.assign[class])
        elseif b:IsShown() then
            SetAction(b, nil)
            b:Hide()
        end
    end
    bar:SetWidth(x - GAP + PAD)
    for _, fn in ipairs(ns.onRefresh) do fn() end
end

-- Several events arrive together (a raid's UNIT_AURA); they share one refresh.
local scheduled = false
local function Schedule()
    if scheduled then return end
    scheduled = true
    C_Timer.After(0.2, function()
        scheduled = false
        ns.Refresh()
    end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "UNIT_AURA", "SPELLS_CHANGED", "BAG_UPDATE_DELAYED",
                         "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if not db then return end
    if event == "PLAYER_REGEN_DISABLED" then
        -- Fires right before the lockdown: the last moment to stop a drag and to write
        -- the freshest state.
        StopDrag()
        ns.Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Counts were frozen in combat and changes may wait: always refresh at its end
        if ns.barPending then ns.InitBar() else ns.Refresh() end
    else
        Schedule()
    end
end)

-- Range changes fire no event; a ticker keeps targets current out of combat.
local ticker

-- At login. The bar is protected once it holds secure buttons, so after a /reload in
-- combat its position waits for the end of combat.
function ns.InitBar()
    if InCombatLockdown() then
        ns.barPending = true
        return
    end
    ns.barPending = false
    ns.LoadPosition()
    ns.ApplyLock()
    ns.Refresh()
    if not ticker then
        ticker = C_Timer.NewTicker(1, function()
            if not InCombatLockdown() then ns.Refresh() end
        end)
    end
end
