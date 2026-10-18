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
controls.hideCombat = UI.AddCheck("OPT_HIDE_COMBAT", "hideCombat", function() ns.ApplyCombatHide() end)
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

-- Orientation and growth direction (anchor point of the bar)
local RefreshDirection
controls.layout = select(2, UI.AddDropdown("OPT_LAYOUT", {
    { value = false, text = function() return L.HORIZONTAL end },
    { value = true,  text = function() return L.VERTICAL end },
}, function() return db.vertical end, function(v)
    db.vertical = v
    if RefreshDirection then RefreshDirection() end -- direction texts (right/left or down/up)
    ns.Refresh()
end))
RefreshDirection, controls.direction = UI.AddDropdown("OPT_DIRECTION", {
    { value = false, text = function() return (db and db.vertical) and L.DIR_DOWN or L.DIR_RIGHT end },
    { value = true,  text = function() return (db and db.vertical) and L.DIR_UP or L.DIR_LEFT end },
}, function() return db.growRev end, function(v)
    db.growRev = v
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

-- Bottom row: "Reload UI" right (own translation, so it follows the language)
do
    local reload = UI.AddButton(general, "RELOAD_UI", function() ReloadUI() end)
    reload:SetPoint("BOTTOMRIGHT", general, "BOTTOMRIGHT", -INSET, INSET - 4)
    controls.reload = reload
    measures[#measures + 1] = function() return reload:GetWidth() end
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

-- The count on the class buttons
UI.AddHeader("TRACK_BLESSINGS", 6)
controls.countColor = select(2, UI.AddToggleColorRow(nil, nil, nil, {
    { label = "LBL_TEXT", key = "countColor" },
}))
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

UI.CreateTabs()
