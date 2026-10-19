-- SimpleBlessingBar - settings pages
-- The pages of the settings window, built with the helpers of Settings.lua (ns.UI).

local _, ns = ...
if not ns.enabled then return end

local D, L, UI = ns.D, ns.L, ns.UI
local INSET, Place = UI.INSET, UI.Place
local refreshers, measures, stretchers = UI.refreshers, UI.measures, UI.stretchers

local db
ns.OnDBReady(function(d) db = d end)

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------
local general = UI.NewPage("TAB_GENERAL")
-- The page's controls by name, for the specs
local controls = {}
UI.controls = controls

-- Language: "Automatic" always follows the client language, otherwise a fixed choice
-- (saved account-wide)
do
    local opts = { { value = "auto", text = function()
        return L.LANG_AUTO:format(ns.LOCALE_NAMES[ns.clientLocale] or ns.clientLocale)
    end } }
    for _, code in ipairs(ns.LOCALE_ORDER) do
        opts[#opts + 1] = { value = code, text = function() return ns.LOCALE_NAMES[code] end }
    end
    controls.language = select(2, UI.AddDropdown("OPT_LANGUAGE", opts, function()
        return SimpleBlessingBarGlobalDB.language or "auto"
    end, function(v)
        SimpleBlessingBarGlobalDB.language = (v ~= "auto") and v or nil
        ns.ApplyLanguage(v == "auto" and ns.clientLocale or v)
    end))
end
controls.hideCombat, controls.hideMinimap = UI.AddCheckRow({
    { label = "OPT_HIDE_COMBAT",  key = "hideCombat",  onChange = function() ns.ApplyCombatHide() end },
    { label = "OPT_HIDE_MINIMAP", key = "hideMinimap", onChange = function() ns.ApplyMinimapButton() end },
})
UI.AddSeparator()

-- Scale: slider in 0.1 steps or number input (0.05 steps)
do
    local ROW = 40
    local row = CreateFrame("Frame", nil, general)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", INSET, Place(ROW, 6))

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 0, -4)
    ns.SetL(label, "OPT_SCALE")

    local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    box:SetSize(44, 20)
    box:SetPoint("TOPRIGHT", 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(4)
    box:SetJustifyH("CENTER")
    controls.scaleBox = box

    local slider = UI.MakeSlider(row)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 2, -10)
    slider:SetMinMaxValues(D.SCALE_MIN, D.SCALE_MAX)
    slider:SetValueStep(0.05) -- fine step, so typed 0.05 values stay where they are
    controls.scaleSlider = slider

    local function Round(v, step) return math.floor(v / step + 0.5) * step end
    local function Format(v) return (("%.2f"):format(v):gsub("0$", "")) end -- 1.00 -> 1.0, 1.05 stays

    local updating = false
    local function SetScaleValue(v, fromSlider)
        v = math.max(D.SCALE_MIN, math.min(D.SCALE_MAX, v))
        v = Round(v, fromSlider and 0.1 or 0.05)
        db.scale = tonumber(("%.2f"):format(v))
        updating = true
        slider:SetValue(db.scale)
        updating = false
        box:SetText(Format(db.scale))
        ns.ApplyScale()
    end

    slider:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        SetScaleValue(v, true) -- dragging snaps to 0.1 steps
    end)
    slider:SetScript("OnMouseWheel", function(_, delta)
        SetScaleValue(db.scale + delta * 0.1, true)
    end)

    local function ApplyBox(self)
        local text = (self:GetText() or ""):gsub(",", ".") -- allow a comma as decimal separator
        local v = tonumber(text)
        -- v == v rejects NaN
        if v and v == v then SetScaleValue(v, false) else self:SetText(Format(db.scale)) end
        self:ClearFocus()
    end
    box:SetScript("OnEnterPressed", ApplyBox)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(Format(db.scale))
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self) self:SetText(Format(db.scale)) end)

    refreshers[#refreshers + 1] = function()
        updating = true
        slider:SetValue(db.scale)
        updating = false
        box:SetText(Format(db.scale))
    end
    measures[#measures + 1] = function() return label:GetStringWidth() + 16 + 44 end
    stretchers[#stretchers + 1] = function(w)
        row:SetWidth(w)
        slider:SetWidth(w - 4)
    end
end

controls.border = UI.AddCheck("OPT_BORDER", "showBorder", function() ns.ApplyLook() end)
controls.bg = UI.AddSwatch("OPT_BG", "bg", 8)
UI.AddSeparator()

-- Orientation, growth direction (anchor point of the bar) and flyout direction
local RefreshDirection, RefreshFlyDir
controls.layout = select(2, UI.AddDropdown("OPT_LAYOUT", {
    { value = false, text = function() return L.HORIZONTAL end },
    { value = true,  text = function() return L.VERTICAL end },
}, function() return db.vertical end, function(v)
    db.vertical = v
    -- Both direction dropdowns name their choices by orientation (right/left or down/up)
    if RefreshDirection then RefreshDirection() end
    if RefreshFlyDir then RefreshFlyDir() end
    ns.Refresh()
end))
RefreshDirection, controls.direction = UI.AddDropdown("OPT_DIRECTION", {
    { value = false, text = function() return (db and db.vertical) and L.DIR_DOWN or L.DIR_RIGHT end },
    { value = true,  text = function() return (db and db.vertical) and L.DIR_UP or L.DIR_LEFT end },
}, function() return db.growRev end, function(v)
    db.growRev = v
    ns.Refresh()
end)
RefreshFlyDir, controls.flyDir = UI.AddDropdown("OPT_FLYDIR", {
    { value = "AUTO",   text = function() return L.FLYDIR_AUTO end },
    { value = "FIRST",  text = function() return (db and db.vertical) and L.DIR_RIGHT or L.DIR_UP end },
    { value = "SECOND", text = function() return (db and db.vertical) and L.DIR_LEFT or L.DIR_DOWN end },
}, function() return db.flyoutDir end, function(v)
    db.flyoutDir = v
    ns.Refresh()
end)

UI.AddSeparator()

-- Demo mode changes the protected bar, so it is refused in combat
controls.demo = UI.AddCheck("OPT_DEMO", "demo", function()
    if InCombatLockdown() then
        db.demo = not db.demo
        controls.demo:SetChecked(db.demo)
        ns.Print(L.NOT_IN_COMBAT)
        return
    end
    ns.Refresh()
end)

-- Bottom row: "Report bug" left, "Reload UI" right (own translations, so they follow the language)
do
    local reload = UI.AddButton(general, "RELOAD_UI", function() ReloadUI() end)
    reload:SetPoint("BOTTOMRIGHT", general, "BOTTOMRIGHT", -INSET, INSET - 4)
    controls.reload = reload
    local bug = UI.AddButton(general, "BTN_REPORT_BUG", function() ns.OpenBugReport() end)
    bug:SetPoint("BOTTOMLEFT", general, "BOTTOMLEFT", INSET, INSET - 4)
    controls.reportBug = bug
    measures[#measures + 1] = function() return bug:GetWidth() + 12 + reload:GetWidth() end
    -- Reserve the space, so the button never overlaps the last element
    Place(22, 8)
end

---------------------------------------------------------------------------
-- Tracking
---------------------------------------------------------------------------
UI.NewPage("TAB_TRACKING")
local function Refresh() ns.Refresh() end

controls.auraHeader = UI.AddHeader("TRACK_AURA", 6)
controls.showAura, controls.auraColor = UI.AddToggleColorRow("OPT_SHOW_BUTTON", "showAura", Refresh, {
    { label = "LBL_HIGHLIGHT", key = "auraAntsColor" },
})
controls.auraSpeed = UI.AddSpeedSlider("auraAntsSpeed")
UI.AddSeparator()

-- Righteous Fury is a spell: the client names it (localization.md)
controls.furyHeader = UI.AddHeader(function()
    return ns.LocalName(C_Spell.GetSpellName(D.RIGHTEOUS_FURY), "RIGHTEOUS_FURY")
end, 6)
controls.showFury, controls.furyColor = UI.AddToggleColorRow("OPT_SHOW_BUTTON", "showFury", Refresh, {
    { label = "LBL_HIGHLIGHT", key = "furyAntsColor" },
})
do
    local slider, _, value = UI.AddSpeedSlider("furyAntsSpeed")
    controls.furySpeed, controls.furySpeedText = slider, value
end
UI.AddSeparator()

-- The blessing button: shown or not, its ants, and the count color of both queue buttons
controls.blessingHeader = UI.AddHeader("BTN_BLESSINGS", 6)
controls.showBlessing, controls.blessingColors = UI.AddToggleColorRow("OPT_SHOW_BUTTON", "showBlessing", Refresh, {
    { label = "LBL_HIGHLIGHT", key = "blessingAntsColor" },
    { label = "LBL_TEXT",      key = "countColor" },
})
controls.blessingSpeed = UI.AddSpeedSlider("blessingAntsSpeed")
UI.AddSeparator()

-- The Salvation button; Salvation is a spell, so the client names it (localization.md)
controls.salvationHeader = UI.AddHeader(function()
    return ns.LocalName(C_Spell.GetSpellName(D.SALVATION), "SALVATION")
end, 6)
controls.showSalvation, controls.salvationColors = UI.AddToggleColorRow("OPT_SHOW_BUTTON", "showSalvation", Refresh, {
    { label = "LBL_HIGHLIGHT", key = "salvationAntsColor" },
})
controls.salvationSpeed = UI.AddSpeedSlider("salvationAntsSpeed")
UI.AddSeparator()

-- Flyout auto-close: the time slider is dimmed while it is off
UI.AddHeader("TRACK_FLYOUTS", 6)
local autoCloseRow
local function ApplyAutoCloseState()
    autoCloseRow:SetAlpha(db.flyoutAutoClose and 1 or 0.4)
end
controls.autoClose = UI.AddCheck("OPT_AUTOCLOSE", "flyoutAutoClose", function()
    ApplyAutoCloseState()
    ns.Refresh()
end)
controls.autoCloseTime, autoCloseRow = UI.AddIntSlider("OPT_AUTOCLOSE_TIME", "flyoutAutoCloseTime",
    D.AUTOCLOSE_MIN, D.AUTOCLOSE_MAX, function(v) return L.SECONDS:format(v) end, Refresh, 6)
controls.autoCloseRow = autoCloseRow
refreshers[#refreshers + 1] = ApplyAutoCloseState

---------------------------------------------------------------------------
-- Supplies: the Symbol of Kings count and the auto-buy
---------------------------------------------------------------------------
UI.NewPage("TAB_SUPPLIES")

-- An item name: the client names it (localization.md)
UI.AddHeader(function()
    return ns.LocalName(C_Item.GetItemNameByID(D.SYMBOL_OF_KINGS), "SYMBOL_OF_KINGS")
end, 6)
controls.symbolWarn, controls.symbolWarnBox = UI.AddNumberSlider({
    label = "OPT_SYMBOL_WARN", key = "symbolWarn", gap = 6, onChange = Refresh,
})
do
    local swatches = select(2, UI.AddToggleColorRow(nil, nil, nil, {
        { label = "LBL_WARNING", key = "symbolWarnColor" },
        { label = "LBL_EMPTY",   key = "symbolZeroColor" },
    }))
    controls.symbolWarnColor, controls.symbolZeroColor = swatches[1], swatches[2]
end
UI.AddSeparator()

-- Auto-buy: the amounts are dimmed while it is off
UI.AddHeader("AUTOBUY_HEADER", 6)
local amountRows = {}
local function ApplyAutoBuyState()
    for _, row in ipairs(amountRows) do row:SetAlpha(db.autoBuy and 1 or 0.4) end
end
controls.autoBuy = UI.AddCheck("OPT_AUTOBUY", "autoBuy", ApplyAutoBuyState)
refreshers[#refreshers + 1] = ApplyAutoBuyState
controls.symbolAmount = UI.AddNumberSlider({
    label = "OPT_SYMBOL_AMOUNT", key = "symbolAmount", gap = 6, rows = amountRows,
})
controls.goldReserve = UI.AddNumberSlider({
    label = "OPT_GOLD_RESERVE", key = "goldReserve", gap = 6, rows = amountRows,
})
controls.amountRows = amountRows

---------------------------------------------------------------------------
-- Order: the bar's order by drag and drop, as in SimpleConjureBar
---------------------------------------------------------------------------
local orderPage = UI.NewPage("TAB_ORDER")

-- Name and icon per row
local ORDER_INFO = {
    AURA      = { name = function() return L.TRACK_AURA end,
                  icon = function() return C_Spell.GetSpellTexture(D.AURAS[db.aura][1]) end },
    FURY      = { name = function() return ns.LocalName(C_Spell.GetSpellName(D.RIGHTEOUS_FURY), "RIGHTEOUS_FURY") end,
                  icon = function() return C_Spell.GetSpellTexture(D.RIGHTEOUS_FURY) end },
    BLESSING  = { name = function() return L.BTN_BLESSINGS end,
                  icon = function() return C_Spell.GetSpellTexture(D.BLESSINGS.KINGS.normal[1]) end },
    SALVATION = { name = function() return ns.LocalName(C_Spell.GetSpellName(D.SALVATION), "SALVATION") end,
                  icon = function() return C_Spell.GetSpellTexture(D.SALVATION) end },
}

do
    UI.AddNote("ORDER_HINT", 10)

    local ROW, ROW_GAP = 26, 2
    local rows = {}
    controls.orderRows = rows
    local RefreshOrder
    local drag -- { key, index } while dragging

    -- Row under the mouse cursor (1..n), no matter where exactly the row is grabbed
    local function SlotUnderCursor()
        local top = rows[1]:GetTop()
        if not top then return end
        local _, cy = GetCursorPosition()
        cy = cy / rows[1]:GetEffectiveScale()
        local slot = math.floor((top - cy) / (ROW + ROW_GAP)) + 1
        return math.max(1, math.min(#rows, slot))
    end

    local function StopOrderDrag()
        if not drag then return end
        drag = nil
        orderPage:SetScript("OnUpdate", nil)
        RefreshOrder()
        ns.Refresh() -- the bar is rebuilt only once the row is dropped
    end

    local function OnDragUpdate()
        -- Safety net: the mouse button was released outside the window
        if not IsMouseButtonDown("LeftButton") then StopOrderDrag() return end
        local slot = SlotUnderCursor()
        if slot and slot ~= drag.index then
            -- The row moves live under the cursor
            table.remove(db.order, drag.index)
            table.insert(db.order, slot, drag.key)
            drag.index = slot
            RefreshOrder()
        end
    end

    local function StartOrderDrag(index)
        drag = { key = db.order[index], index = index }
        RefreshOrder()
        orderPage:SetScript("OnUpdate", OnDragUpdate)
    end

    for i = 1, #D.DEFAULT_ORDER do
        local row = CreateFrame("Frame", nil, orderPage)
        row:SetHeight(ROW)
        row:SetPoint("TOPLEFT", INSET, Place(ROW, ROW_GAP))
        row:EnableMouse(true)

        -- Background: subtle on hover, gold while dragging
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0)

        row.num = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.num:SetPoint("LEFT", 4, 0)
        row.num:SetWidth(16)
        row.num:SetJustifyH("RIGHT")
        row.num:SetText(i .. ".")

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", row.num, "RIGHT", 6, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)

        -- Burger grip (three lines) on the right shows that the row can be dragged
        row.grip = {}
        for k = 1, 3 do
            local line = row:CreateTexture(nil, "ARTWORK")
            line:SetSize(14, 2)
            line:SetPoint("RIGHT", row, "RIGHT", -6, (2 - k) * 5)
            line:SetColorTexture(0.6, 0.6, 0.6, 1)
            row.grip[k] = line
        end
        function row.SetGripColor(r, g, b)
            for _, line in ipairs(row.grip) do line:SetColorTexture(r, g, b, 1) end
        end

        row:SetScript("OnEnter", function(self)
            if drag then return end
            self.bg:SetColorTexture(1, 1, 1, 0.06)
            self.SetGripColor(1, 0.82, 0)
        end)
        row:SetScript("OnLeave", function(self)
            if drag then return end
            self.bg:SetColorTexture(1, 1, 1, 0)
            self.SetGripColor(0.6, 0.6, 0.6)
        end)
        row:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then StartOrderDrag(i) end
        end)
        row:SetScript("OnMouseUp", function(_, btn)
            if btn == "LeftButton" then StopOrderDrag() end
        end)

        rows[i] = row
        measures[#measures + 1] = function() return 4 + 16 + 6 + 22 + 8 + row.label:GetStringWidth() + 16 + 20 end
        stretchers[#stretchers + 1] = function(w) row:SetWidth(w) end
    end

    RefreshOrder = function()
        for i, row in ipairs(rows) do
            local info = ORDER_INFO[db.order[i]]
            row.label:SetText(info.name())
            row.icon:SetTexture(info.icon())
            if drag and drag.index == i then
                row.bg:SetColorTexture(1, 0.82, 0, 0.18)
                row.SetGripColor(1, 0.82, 0)
            elseif drag or not row:IsMouseOver() then
                row.bg:SetColorTexture(1, 1, 1, 0)
                row.SetGripColor(0.6, 0.6, 0.6)
            end
        end
    end
    refreshers[#refreshers + 1] = RefreshOrder
    orderPage:SetScript("OnHide", StopOrderDrag)

    -- Restores the default order
    local reset = UI.AddButton(orderPage, "DEFAULT", function()
        db.order = { unpack(D.DEFAULT_ORDER) }
        RefreshOrder()
        ns.Refresh()
    end)
    reset:SetPoint("TOPLEFT", INSET, Place(22, 6) - 6)
    controls.orderDefault = reset
end

---------------------------------------------------------------------------
-- Blessings: a priority list per role, dragged and switched off (ruleset plan
-- 2026-10-19-blessing-steering)
---------------------------------------------------------------------------
local blessingsPage = UI.NewPage("TAB_BLESSINGS")

do
    local B = ns.Blessings
    local FamilyName = B.FamilyName

    -- The pin "I give only X": in memory only, so it is not a setting in db
    local pinOptions = { { value = false, text = function() return L.PIN_NONE end } }
    for _, family in ipairs(D.BLESSING_ORDER) do
        pinOptions[#pinOptions + 1] = { value = family, text = function() return FamilyName(family) end }
    end
    local _, pinDropdown = UI.AddDropdown("PIN_LABEL", pinOptions,
        function() return B.pin or false end,
        function(family)
            B.pin = family or nil
            ns.Refresh()
        end)
    controls.pin = pinDropdown

    UI.AddNote("LISTS_HINT", 10, 2)

    local ICON, ICON_GAP, LABEL_W = 24, 6, 120
    local rows = {}
    controls.listRows = rows
    local RefreshLists
    local drag -- { row, index } while dragging

    -- The families of a row as shown: those on, in order, then those off in D.BLESSING_ORDER
    local function Shown(list)
        local out = { unpack(list.order) }
        for _, family in ipairs(D.BLESSING_ORDER) do
            if list.off[family] then out[#out + 1] = family end
        end
        return out
    end

    -- The slot under the cursor among the icons that are on
    local function SlotUnderCursor(row)
        local left = row.icons[1]:GetLeft()
        if not left then return end
        local cx = GetCursorPosition() / row.icons[1]:GetEffectiveScale()
        local slot = math.floor((cx - left) / (ICON + ICON_GAP)) + 1
        return math.max(1, math.min(#db.roleLists[row.role].order, slot))
    end

    local function StopListDrag()
        if not drag then return end
        drag = nil
        blessingsPage:SetScript("OnUpdate", nil)
        RefreshLists()
        ns.Refresh() -- the queue is rebuilt only once the icon is dropped
    end

    local function OnDragUpdate()
        -- Safety net: the mouse button was released outside the window
        if not IsMouseButtonDown("LeftButton") then StopListDrag() return end
        local row = rows[drag.row]
        local slot = SlotUnderCursor(row)
        if slot and slot ~= drag.index then
            local order = db.roleLists[row.role].order
            table.insert(order, slot, table.remove(order, drag.index))
            drag.index = slot
            RefreshLists()
        end
    end

    -- A right click switches a family off, greyed after the others, or on again, appended to
    -- the ones on. At least one stays on.
    local function Toggle(role, family)
        local list = db.roleLists[role]
        if list.off[family] then
            list.off[family] = nil
            table.insert(list.order, family)
        elseif #list.order > 1 then
            for i, f in ipairs(list.order) do
                if f == family then table.remove(list.order, i) break end
            end
            list.off[family] = true
        end
        RefreshLists()
        ns.Refresh()
    end

    for r, role in ipairs(D.ROLES) do
        local row = CreateFrame("Frame", nil, blessingsPage)
        row:SetHeight(ICON)
        row:SetPoint("TOPLEFT", INSET, Place(ICON, 6))
        row.role = role
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", 4, 0)
        row.label:SetWidth(LABEL_W)
        row.label:SetJustifyH("LEFT")
        ns.SetL(row.label, "ROLE_" .. role)

        row.icons = {}
        for i = 1, #D.BLESSING_ORDER do
            local icon = CreateFrame("Button", nil, row)
            icon:SetSize(ICON, ICON)
            icon:SetPoint("LEFT", row.label, "RIGHT", (i - 1) * (ICON + ICON_GAP), 0)
            icon.tex = icon:CreateTexture(nil, "ARTWORK")
            icon.tex:SetAllPoints()
            icon.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            icon:SetScript("OnMouseDown", function(_, btn)
                -- Only an icon that is on moves; those off keep their place at the end
                if btn ~= "LeftButton" or i > #db.roleLists[role].order then return end
                drag = { row = r, index = i }
                RefreshLists()
                blessingsPage:SetScript("OnUpdate", OnDragUpdate)
            end)
            icon:SetScript("OnMouseUp", function(self, btn)
                if btn == "LeftButton" then
                    StopListDrag()
                elseif btn == "RightButton" then
                    Toggle(role, self.family)
                end
            end)
            icon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(FamilyName(self.family))
                GameTooltip:Show()
            end)
            icon:SetScript("OnLeave", ns.HideTooltip)
            row.icons[i] = icon
        end

        rows[r] = row
        measures[#measures + 1] = function() return 4 + LABEL_W + #D.BLESSING_ORDER * (ICON + ICON_GAP) + 20 end
        stretchers[#stretchers + 1] = function(w) row:SetWidth(w) end
    end

    RefreshLists = function()
        for r, row in ipairs(rows) do
            local list = db.roleLists[row.role]
            for i, family in ipairs(Shown(list)) do
                local icon = row.icons[i]
                icon.family = family
                icon.tex:SetTexture(C_Spell.GetSpellTexture(D.BLESSINGS[family].normal[1]))
                icon.tex:SetDesaturated(list.off[family] == true)
                local dragged = drag and drag.row == r and drag.index == i
                icon:SetAlpha(list.off[family] and 0.5 or dragged and 0.7 or 1)
            end
        end
    end
    refreshers[#refreshers + 1] = RefreshLists
    blessingsPage:SetScript("OnHide", StopListDrag)

    -- Restores every row
    local reset = UI.AddButton(blessingsPage, "DEFAULT", function()
        db.roleLists = ns.DefaultRoleLists()
        RefreshLists()
        ns.Refresh()
    end)
    reset:SetPoint("TOPLEFT", INSET, Place(22, 6) - 6)
    controls.listsDefault = reset

    controls.renewMinutes = UI.AddNumberSlider({ label = "RENEW_LABEL", key = "renewMinutes", gap = 14,
        onChange = function() ns.Refresh() end })
end

---------------------------------------------------------------------------
-- Macros: prepared only; which macros are worth it Michel decides in a later plan
---------------------------------------------------------------------------
UI.NewPage("TAB_MACROS")
controls.macrosNote = UI.AddNote("MACROS_LATER", 10)

UI.CreateTabs()
