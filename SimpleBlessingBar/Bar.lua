-- SimpleBlessingBar - the bar
-- Handle, position and lock; one secure button per class in the group. Targets, ranks and
-- counts come from Blessings.lua out of combat; in combat nothing is rewritten and the
-- buttons keep what they had (ruleset plan 2026-10-18-class-blessing-bar).

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings
local SetAttr = ns.SetAttr

local SIZE, GAP = 36, 2
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local db
ns.OnDBReady(function(d) db = d end)

---------------------------------------------------------------------------
-- Bar and handle
---------------------------------------------------------------------------
local bar = CreateFrame("Frame", "SimpleBlessingBarFrame", UIParent)
ns.bar = bar
bar:SetSize(SIZE, SIZE)
bar:SetMovable(true)
bar:SetClampedToScreen(true)
bar:SetPoint("CENTER", UIParent, "CENTER", 0, -150) -- start position, replaced at login

local handle = CreateFrame("Frame", nil, bar)
ns.handle = handle
handle:SetSize(10, SIZE)
handle:SetPoint("RIGHT", bar, "LEFT", -1, 0)
handle:EnableMouse(true)
local handleTex = handle:CreateTexture(nil, "BACKGROUND")
handleTex:SetAllPoints()

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
    if db.locked then
        handleTex:SetColorTexture(0.9, 0.25, 0.2, 0.6)
    else
        handleTex:SetColorTexture(0.96, 0.55, 0.73, 0.6)
    end
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
end
handle:SetScript("OnMouseUp", StopDrag)

---------------------------------------------------------------------------
-- Class buttons
---------------------------------------------------------------------------
local buttons = {}
ns.classButtons = buttons

for _, class in ipairs(D.CLASS_ORDER) do
    local b = CreateFrame("Button", "SimpleBlessingBarClass" .. class, bar, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    -- A secure click acts on key down or up per ActionButtonUseKeyDown; both are registered
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.classIcon = b:CreateTexture(nil, "BACKGROUND")
    b.classIcon:SetAllPoints()
    b.classIcon:SetTexture(CLASS_ICONS)
    b.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
    b.blessIcon = b:CreateTexture(nil, "ARTWORK")
    b.blessIcon:SetSize(SIZE / 2, SIZE / 2)
    b.blessIcon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
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
    local x = 0
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
    bar:SetWidth(math.max(SIZE, x - GAP))
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
