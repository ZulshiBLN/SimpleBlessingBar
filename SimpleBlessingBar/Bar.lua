-- SimpleBlessingBar - the bar
-- Handle, position and lock; one secure button per class in the group. Targets, ranks and
-- counts come from Blessings.lua out of combat; in combat nothing is rewritten and the
-- buttons keep what they had (ruleset plan 2026-10-18-class-blessing-bar).

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings
local SetAttr = ns.SetAttr

local SIZE, GAP, PAD = D.SIZE, D.GAP, D.PAD
-- Square class icons, cut like spell icons. The character creation sprite carries its own
-- round frame and looked like a classic button beside the others (Michel, 2026-10-18).
local CLASS_ICON = "Interface\\Icons\\ClassIcon_"

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

-- The highlight ("marching ants" like spell procs in the Retail client), as in
-- SimpleConjureBar, shared by the aura, Righteous Fury and class buttons. It sits on its own
-- frame above the button; the animation runs (OnUpdate) only while the highlight is visible.
-- Color and speed are settings: colorKey and speedKey name them. ns.ApplyLook colors them.
local antsButtons = {}
function ns.AttachAnts(b, colorKey, speedKey)
    local holder = CreateFrame("Frame", nil, b)
    holder:SetAllPoints()
    holder:SetFrameLevel(b:GetFrameLevel() + 2)

    local ants = holder:CreateTexture(nil, "OVERLAY")
    ants:SetTexture(D.ANTS_TEX)
    ants:SetDesaturated(true)
    ants:SetBlendMode("ADD")
    ants:SetPoint("CENTER")
    ants:SetSize(SIZE * 1.42, SIZE * 1.42)
    ants:Hide()

    local frame, timer = 0, 0
    local function SetFrame(i)
        local col, row = i % D.ANTS_COLS, math.floor(i / D.ANTS_COLS)
        ants:SetTexCoord(col * D.ANTS_CELL, (col + 1) * D.ANTS_CELL, row * D.ANTS_CELL, (row + 1) * D.ANTS_CELL)
    end
    SetFrame(0)

    b.ants, b.antsHolder, b.antsColorKey = ants, holder, colorKey
    b.antsUpdate = function(_, elapsed)
        local step = D.ANTS_STEPS[db[speedKey]]
        timer = timer + elapsed
        if timer < step then return end
        frame = (frame + math.floor(timer / step)) % D.ANTS_FRAMES
        timer = timer % step
        SetFrame(frame)
    end
    antsButtons[#antsButtons + 1] = b
end

-- Shows or hides a button's highlight and starts or stops its animation
function ns.SetAnts(b, shown)
    if shown == b.antsShown then return end
    b.antsShown = shown
    if shown then
        b.ants:Show()
        b.antsHolder:SetScript("OnUpdate", b.antsUpdate)
    else
        b.ants:Hide()
        b.antsHolder:SetScript("OnUpdate", nil)
    end
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
-- SimpleConjureBar's handle tooltip: the lock state and what each click does
local function ShowHandleTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("SimpleBlessingBar")
    if db.locked then
        GameTooltip:AddLine(L.TIP_LOCKED, 1, 0.3, 0.3)
    else
        GameTooltip:AddLine(L.TIP_UNLOCKED, 0.4, 0.8, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.LEFTCLICK, L.MOVE, 0, 1, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.RIGHTCLICK, db.locked and L.UNLOCK or L.LOCK, 0, 1, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.MIDDLECLICK, L.SETTINGS, 0, 1, 0, 1, 1, 1)
    GameTooltip:Show()
end
handle:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    ShowHandleTooltip(self)
end)
handle:SetScript("OnLeave", function(self)
    if not self.moving then self:SetAlpha(0) end
    GameTooltip:Hide()
end)

function ns.LoadPosition()
    bar:ClearAllPoints()
    bar:SetPoint(db.point or "CENTER", UIParent, db.rel or "CENTER", db.x or 0, db.y or -150)
end

-- The anchor point depends on orientation and growth: the bar grows away from it when
-- buttons are added (right -> left edge, left -> right edge and so on), as in SimpleConjureBar.
function ns.AnchorPoint()
    if db.vertical then return db.growRev and "BOTTOM" or "TOP" end
    return db.growRev and "RIGHT" or "LEFT"
end

-- Re-anchors the bar at its anchor point without moving it on screen, and saves the position
function ns.ReAnchor()
    if InCombatLockdown() then return end
    local l, b, w, h = bar:GetRect()
    if not l then return end
    local point = ns.AnchorPoint()
    local x, y
    if point == "LEFT" then x, y = l, b + h / 2
    elseif point == "RIGHT" then x, y = l + w, b + h / 2
    elseif point == "TOP" then x, y = l + w / 2, b + h
    else x, y = l + w / 2, b end
    bar:ClearAllPoints()
    bar:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
    db.point, db.rel, db.x, db.y = point, "BOTTOMLEFT", x, y
end

-- Scale 0.5 - 2.0, out of combat only. The bar stays at the same screen position: positions
-- are stored in the scaled coordinate system and are converted.
local scalePending = false
function ns.ApplyScale()
    if InCombatLockdown() then scalePending = true return end -- the bar is protected in combat
    scalePending = false
    local new, old = db.scale, bar:GetScale()
    if math.abs(new - old) < 0.001 then return end
    local cx, cy = bar:GetCenter()
    bar:SetScale(new)
    if cx and cy then
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * old / new, cy * old / new)
        ns.ReAnchor()
    end
end

-- Hide in combat: a secure state driver, set or cleared out of combat only
local combatPending = false
function ns.ApplyCombatHide()
    if InCombatLockdown() then combatPending = true return end
    combatPending = false
    if db.hideCombat then
        RegisterStateDriver(bar, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(bar, "visibility")
        bar:Show()
    end
end

-- Background and border of the bar and of every flyout, the class buttons' count color and
-- every button's ants. None of it is protected, so this works in combat too.
function ns.ApplyLook()
    local c, e = db.bg, D.BORDER_COLOR
    local frames = { bar }
    for _, fly in pairs(ns.flyouts or {}) do frames[#frames + 1] = fly end
    for _, f in ipairs(frames) do
        f:SetBackdropColor(c.r, c.g, c.b, c.a)
        f:SetBackdropBorderColor(e.r, e.g, e.b, db.showBorder and e.a or 0)
    end
    local n = db.countColor
    for _, b in pairs(ns.classButtons) do b.count:SetTextColor(n.r, n.g, n.b, n.a) end
    for _, b in ipairs(antsButtons) do
        local a = db[b.antsColorKey]
        b.ants:SetVertexColor(a.r, a.g, a.b, a.a)
    end
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
        ShowHandleTooltip(self) -- the tooltip shows the new state
    elseif button == "MiddleButton" then
        ns.ToggleSettings() -- refuses to open in combat itself
    end
end)

-- StopMovingOrSizing must not be called once the lockdown is active.
local function StopDrag()
    if not handle.moving then return end
    handle.moving = false
    if InCombatLockdown() then return end
    bar:StopMovingOrSizing()
    ns.ReAnchor()
    ns.Refresh() -- the flyout direction follows the screen half
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
    b.classIcon:SetTexture(CLASS_ICON .. class)
    b.blessIcon = b:CreateTexture(nil, "ARTWORK")
    b.blessIcon:SetSize(SIZE / 2 - 2, SIZE / 2 - 2)
    b.blessIcon:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1)
    b.blessIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b:SetScript("OnEnter", ns.ShowSpellTooltip)
    b:SetScript("OnLeave", ns.HideTooltip)
    ns.AttachAnts(b, "classAntsColor", "classAntsSpeed")
    -- The Symbols of Kings in the bags, centred above the icons (Michel, 2026-10-18)
    b.symbols = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.symbols:SetPoint("CENTER", 0, 0)
    b.class = class
    b:Hide()
    buttons[class] = b
end

-- Left click only: right click stays free for the flyout. In demo mode the button keeps its
-- spell (tooltip, the demo print) but gets no secure action, so it casts nothing.
local function SetAction(b, spell, unit)
    SetAttr(b, "type1", (spell and not ns.IsDemo()) and "spell" or nil)
    SetAttr(b, "spell1", spell)
    SetAttr(b, "unit1", spell and unit or nil)
end

-- The Symbol count: white, the warning color at or below the threshold, the empty color at 0
local WHITE = { r = 1, g = 1, b = 1, a = 1 }
local function UpdateSymbols(b, shown)
    if not shown then
        b.symbols:SetText("")
        return
    end
    local n = ns.IsDemo() and D.DEMO_SYMBOLS or C_Item.GetItemCount(D.SYMBOL_OF_KINGS)
    local c = WHITE
    if n == 0 then c = db.symbolZeroColor
    elseif db.symbolWarn > 0 and n <= db.symbolWarn then c = db.symbolWarnColor end
    b.symbols:SetText(tostring(n))
    b.symbols:SetTextColor(c.r, c.g, c.b, c.a)
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
    -- The count and the ants show only while members lack the blessing; a 0 shows nothing
    local lacking = state.castable and state.count > 0
    b.count:SetText(lacking and tostring(state.count) or "")
    ns.SetAnts(b, lacking)
    UpdateSymbols(b, state.castable and B.Rank(D.BLESSINGS[family].greater) ~= nil)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
-- Other buttons on the bar refresh with it: functions added here run after the class
-- buttons, out of combat only.
ns.onRefresh = {}

-- Flyout direction: the player's fixed choice, or SimpleConjureBar's rule - a horizontal bar
-- opens up in the lower half of the screen and down in the upper; a vertical bar opens right
-- in the left half and left in the right.
local function ComputeFlyDir()
    if db.flyoutDir == "FIRST" then return db.vertical and "RIGHT" or "UP" end
    if db.flyoutDir == "SECOND" then return db.vertical and "LEFT" or "DOWN" end
    local cx, cy = bar:GetCenter()
    if not cx then return db.vertical and "RIGHT" or "UP" end
    local s = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
    cx, cy = cx * s, cy * s
    if db.vertical then
        return (cx > UIParent:GetWidth() / 2) and "LEFT" or "RIGHT"
    end
    return (cy > UIParent:GetHeight() / 2) and "DOWN" or "UP"
end

-- Places the shown buttons from the anchor point, sizes the bar, puts the handle on the
-- anchor side.
local function Arrange(shown)
    local point = ns.AnchorPoint()
    for i, b in ipairs(shown) do
        local off = PAD + (i - 1) * (SIZE + GAP)
        b:ClearAllPoints()
        if point == "LEFT" then b:SetPoint("LEFT", bar, "LEFT", off, 0)
        elseif point == "RIGHT" then b:SetPoint("RIGHT", bar, "RIGHT", -off, 0)
        elseif point == "TOP" then b:SetPoint("TOP", bar, "TOP", 0, -off)
        else b:SetPoint("BOTTOM", bar, "BOTTOM", 0, off) end
    end
    local long = math.max(1, #shown) * (SIZE + GAP) - GAP + 2 * PAD
    if db.vertical then bar:SetSize(SIZE + 2 * PAD, long) else bar:SetSize(long, SIZE + 2 * PAD) end

    handle:ClearAllPoints()
    if point == "LEFT" then
        handle:SetSize(10, SIZE); handle:SetPoint("RIGHT", bar, "LEFT", -1, 0)
    elseif point == "RIGHT" then
        handle:SetSize(10, SIZE); handle:SetPoint("LEFT", bar, "RIGHT", 1, 0)
    elseif point == "TOP" then
        handle:SetSize(SIZE, 10); handle:SetPoint("BOTTOM", bar, "TOP", 0, 1)
    else
        handle:SetSize(SIZE, 10); handle:SetPoint("TOP", bar, "BOTTOM", 0, -1)
    end
end

-- Reads the group out of combat and writes everything to the buttons. In combat it does
-- nothing: aura data is unreadable then and the buttons are protected.
-- PLAYER_REGEN_ENABLED runs it again, which also applies anything ns.SetAttr skipped.
function ns.Refresh()
    if not db or InCombatLockdown() then return end
    ns.attrPending = false

    -- The aura and Righteous Fury buttons first, each if the settings show it, then the
    -- classes in the group. A hidden button leaves no gap.
    local shown = {}
    for _, own in ipairs({ { ns.auraButton, "showAura" }, { ns.furyButton, "showFury" } }) do
        local b, key = own[1], own[2]
        if db[key] then
            shown[#shown + 1] = b
            b:Show()
        else
            b:Hide()
        end
    end
    -- Demo mode shows every class, without reading the roster
    local present = {}
    if ns.IsDemo() then
        for _, class in ipairs(D.CLASS_ORDER) do present[class] = true end
    else
        for _, unit in ipairs(B.Members()) do
            local class = select(2, UnitClass(unit))
            if class then present[class] = true end
        end
    end
    for _, class in ipairs(D.CLASS_ORDER) do
        local b = buttons[class]
        if present[class] then
            shown[#shown + 1] = b
            b:Show()
            Update(b, db.assign[class])
        elseif b:IsShown() then
            SetAction(b, nil)
            ns.SetAnts(b, false)
            b:Hide()
        end
    end
    -- A drag in progress keeps its own anchor; it re-anchors when it ends
    if not handle.moving then ns.ReAnchor() end
    Arrange(shown)
    ns.flyDir = ComputeFlyDir()
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
        if ns.barPending then
            ns.InitBar()
        else
            if scalePending then ns.ApplyScale() end
            if combatPending then ns.ApplyCombatHide() end
            ns.Refresh()
        end
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
    bar:SetScale(db.scale) -- before positioning: the position is stored in the scaled system
    ns.LoadPosition()
    ns.ApplyLock()
    ns.ApplyCombatHide()
    ns.ApplyLook()
    ns.Refresh()
    if not ticker then
        ticker = C_Timer.NewTicker(1, function()
            if not InCombatLockdown() then ns.Refresh() end
        end)
    end
end
