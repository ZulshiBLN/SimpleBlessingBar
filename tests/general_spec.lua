-- SettingsPages.lua: the General page. Each control writes its setting and the bar follows
-- (ruleset plan 2026-10-18-settings-window, IMPLEMENTATION "Tests, by phase" 3).

local addon = require("addon")

local function open()
    local ns = addon.load("enUS", { group = "party", units = { party1 = { class = "MAGE" } } })
    STATE.known = { [ns.D.AURAS.DEVOTION[1]] = true }
    FIRE("PLAYER_LOGIN")
    SlashCmdList.SIMPLEBLESSINGBAR("")
    return ns, ns.UI.controls, SimpleBlessingBarDB
end

local function click(cb, checked)
    cb:SetChecked(checked)
    RUNSCRIPT(cb, "OnClick")
end

-- Picks the menu entry whose text is `text`
local function pick(dd, text)
    for _, e in ipairs(MENU(dd)) do
        if e.text == text then return e.pick() end
    end
    error("no entry " .. tostring(text))
end

local function selected(dd)
    for _, e in ipairs(MENU(dd)) do
        if e.selected then return e.text end
    end
end

describe("the General page", function()
    it("opens without an error", function()
        local ns = open()
        assert.is_true(ns.UI.pages[1]:IsShown())
        assert.are.same({}, STATE.errors)
    end)

    it("lists automatic and every locale, and switches the language", function()
        local ns, c = open()
        local entries = MENU(c.language)
        assert.are.equal(1 + #ns.LOCALE_ORDER, #entries)
        assert.are.equal(ns.L.LANG_AUTO:format("English"), entries[1].text)
        assert.is_true(entries[1].selected)
        pick(c.language, "Deutsch")
        assert.are.equal("deDE", SimpleBlessingBarGlobalDB.language)
        assert.are.equal(ns.locales.deDE.TAB_GENERAL, ns.UI.tabs[1]:GetText())
        assert.are.equal("Deutsch", selected(c.language))
        local auto = MENU(c.language)[1] -- now named in German
        assert.are.equal(ns.locales.deDE.LANG_AUTO:format("English"), auto.text)
        auto.pick()
        assert.is_nil(SimpleBlessingBarGlobalDB.language)
        assert.are.equal(ns.locales.enUS.TAB_GENERAL, ns.UI.tabs[1]:GetText())
    end)

    it("hides the bar in combat through a state driver", function()
        local ns, c, db = open()
        click(c.hideCombat, true)
        assert.is_true(db.hideCombat)
        assert.are.equal("[combat] hide; show", STATE.drivers[ns.bar].visibility)
        click(c.hideCombat, false)
        assert.is_false(db.hideCombat)
        assert.is_nil(STATE.drivers[ns.bar].visibility)
    end)

    it("scales the bar from the slider in 0.1 steps", function()
        local ns, c, db = open()
        c.scaleSlider:SetValue(1.47)
        assert.are.equal(1.5, db.scale)
        assert.are.equal(1.5, ns.bar:GetScale())
        assert.are.equal("1.5", c.scaleBox:GetText())
    end)

    it("scales the bar from the box in 0.05 steps, with a comma, clamped", function()
        local ns, c, db = open()
        c.scaleBox:SetText("1,25")
        RUNSCRIPT(c.scaleBox, "OnEnterPressed")
        assert.are.equal(1.25, db.scale)
        assert.are.equal(1.25, ns.bar:GetScale())
        c.scaleBox:SetText("9")
        RUNSCRIPT(c.scaleBox, "OnEnterPressed")
        assert.are.equal(ns.D.SCALE_MAX, db.scale)
        c.scaleBox:SetText("abc")
        RUNSCRIPT(c.scaleBox, "OnEnterPressed")
        assert.are.equal(ns.D.SCALE_MAX, db.scale)
        assert.are.equal("2.0", c.scaleBox:GetText())
    end)

    it("waits for the end of combat with a scale or combat-hide change", function()
        local ns, c, db = open()
        STATE.combat = true
        c.scaleSlider:SetValue(0.8)
        click(c.hideCombat, true)
        assert.are.equal(0.8, db.scale)
        assert.are.equal(1, ns.bar:GetScale())
        assert.is_nil((STATE.drivers or {})[ns.bar])
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.are.equal(0.8, ns.bar:GetScale())
        assert.are.equal("[combat] hide; show", STATE.drivers[ns.bar].visibility)
        assert.are.same({}, STATE.errors)
    end)

    it("shows and hides the border of the bar and the flyouts", function()
        local ns, c, db = open()
        click(c.border, false)
        assert.is_false(db.showBorder)
        assert.are.equal(0, ns.bar.borderColor[4])
        assert.are.equal(0, ns.flyouts.AURA.borderColor[4])
        click(c.border, true)
        assert.are.equal(ns.D.BORDER_COLOR.a, ns.bar.borderColor[4])
    end)

    it("colors the background of the bar and the flyouts, and cancels back", function()
        local ns, c, db = open()
        RUNSCRIPT(c.bg, "OnClick")
        assert.is_true(ColorPickerFrame:IsShown())
        STATE.pickedColor = { 1, 0, 0, 0.5 }
        ColorPickerFrame.info.swatchFunc()
        assert.are.same({ r = 1, g = 0, b = 0, a = 0.5 }, db.bg)
        assert.are.same({ 1, 0, 0, 0.5 }, ns.bar.backdropColor)
        assert.are.same({ 1, 0, 0, 0.5 }, ns.flyouts.MAGE.backdropColor)
        ColorPickerFrame.info.cancelFunc()
        local d = ns.D.BG_COLOR
        assert.are.same({ d.r, d.g, d.b, d.a }, ns.bar.backdropColor)
    end)

    it("resets the background with the color picker's Default button", function()
        local ns, c, db = open()
        RUNSCRIPT(c.bg, "OnClick")
        STATE.pickedColor = { 0, 1, 0, 1 }
        ColorPickerFrame.info.swatchFunc()
        assert.is_true(ns.UI.colorDefault:IsShown())
        RUNSCRIPT(ns.UI.colorDefault, "OnClick")
        assert.are.same(ns.D.BG_COLOR, db.bg)
        assert.are_not.equal(ns.D.BG_COLOR, db.bg) -- a copy, never the default itself
        ColorPickerFrame:Hide()
        assert.is_false(ns.UI.colorDefault:IsShown())
    end)

    -- layout, growth -> the bar's anchor and where the handle sits against the bar
    local LAYOUTS = {
        { "HORIZONTAL", "DIR_RIGHT", "LEFT",   "RIGHT",  { 10, 36 } },
        { "HORIZONTAL", "DIR_LEFT",  "RIGHT",  "LEFT",   { 10, 36 } },
        { "VERTICAL",   "DIR_DOWN",  "TOP",    "BOTTOM", { 36, 10 } },
        { "VERTICAL",   "DIR_UP",    "BOTTOM", "TOP",    { 36, 10 } },
    }
    for _, case in ipairs(LAYOUTS) do
        local layout, dir, anchor, handleSide, handleSize = unpack(case)
        it("lays the bar out " .. layout .. " " .. dir .. " from its " .. anchor, function()
            local ns, c = open()
            pick(c.layout, ns.L[layout])
            pick(c.direction, ns.L[dir])
            assert.are.equal(anchor, (ns.bar:GetPoint()))
            local p, rel, relP = ns.handle:GetPoint()
            assert.are.equal(handleSide, p)
            assert.are.equal(ns.bar, rel)
            assert.are.equal(anchor, relP)
            assert.are.same(handleSize, { ns.handle:GetWidth(), ns.handle:GetHeight() })
        end)
    end

    it("names the growth directions after the layout", function()
        local ns, c = open()
        assert.are.same({ ns.L.DIR_RIGHT, ns.L.DIR_LEFT }, { MENU(c.direction)[1].text, MENU(c.direction)[2].text })
        pick(c.layout, ns.L.VERTICAL)
        assert.are.same({ ns.L.DIR_DOWN, ns.L.DIR_UP }, { MENU(c.direction)[1].text, MENU(c.direction)[2].text })
    end)

    -- layout, centre of the bar on screen -> the flyout's direction
    local HALVES = {
        { "HORIZONTAL", { 500, 300 },  "UP" },
        { "HORIZONTAL", { 500, 800 },  "DOWN" },
        { "VERTICAL",   { 300, 500 },  "RIGHT" },
        { "VERTICAL",   { 1500, 500 }, "LEFT" },
    }
    for _, case in ipairs(HALVES) do
        local layout, center, dir = unpack(case)
        it("opens the flyouts " .. dir .. " for a " .. layout .. " bar at " .. center[1] .. "," .. center[2], function()
            local ns, c = open()
            STATE.center = center
            pick(c.layout, ns.L[layout])
            assert.are.equal(dir, ns.flyDir)
            local lay = ns.D.FLY_LAYOUT[dir]
            assert.are.equal(lay.fly[1], (ns.flyouts.AURA:GetPoint()))
            assert.are.equal(lay.rot, rawget(ns.auraButton.arrow, "rotation"))
        end)
    end

    it("reloads the UI from its button", function()
        local _, c = open()
        RUNSCRIPT(c.reload, "OnClick")
        assert.is_true(STATE.reloaded)
    end)
end)
