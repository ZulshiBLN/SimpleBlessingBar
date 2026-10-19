-- SettingsPages.lua: the Tracking page. Show toggles, the ants' color and speed per button,
-- the count color, the flyout auto-close (ruleset plan 2026-10-18-settings-window,
-- IMPLEMENTATION "Tests, by phase" 4).

local addon = require("addon")

-- A paladin with Devotion Aura and Righteous Fury learned, neither up, in a party with a mage
local function open()
    -- The player a tank, so Righteous Fury's ants run (ruleset plan 2026-10-19-priorities)
    local ns = addon.load("enUS", { group = "party", units = { party1 = { class = "MAGE" },
                                                               player = { class = "PALADIN", role = "TANK" } } })
    local D = ns.D
    STATE.known = { [D.AURAS.DEVOTION[1]] = true, [D.RIGHTEOUS_FURY] = true,
                    [D.BLESSINGS.MIGHT.normal[1]] = true }
    FIRE("PLAYER_LOGIN")
    SlashCmdList.SIMPLEBLESSINGBAR("")
    RUNSCRIPT(ns.UI.tabs[2], "OnClick")
    return ns, ns.UI.controls, SimpleBlessingBarDB, D
end

local function check(cb, checked)
    cb:SetChecked(checked)
    RUNSCRIPT(cb, "OnClick")
end

local function pickColor(swatch, color)
    RUNSCRIPT(swatch, "OnClick")
    STATE.pickedColor = color
    ColorPickerFrame.info.swatchFunc()
end

describe("the Tracking page", function()
    it("opens without an error and names Righteous Fury as the client does", function()
        local ns, c = open()
        assert.is_true(ns.UI.pages[2]:IsShown())
        assert.are.equal("spell" .. ns.D.RIGHTEOUS_FURY, c.furyHeader:GetText())
        ns.ApplyLanguage("deDE") -- the addon no longer speaks the client's language
        assert.are.equal(ns.locales.deDE.RIGHTEOUS_FURY, c.furyHeader:GetText())
        assert.are.same({}, STATE.errors)
    end)

    for _, case in ipairs({ { "aura", "showAura" }, { "fury", "showFury" } }) do
        local which, key = case[1], case[2]
        it("hides the " .. which .. " button and closes its gap, in every layout", function()
            local ns, c, db, D = open()
            local button = ns[which .. "Button"]
            local other = which == "aura" and ns.furyButton or ns.auraButton
            check(c[key], false)
            assert.is_false(db[key])
            assert.is_false(button:IsShown())
            for _, layout in ipairs({ { false, false }, { false, true }, { true, false }, { true, true } }) do
                db.vertical, db.growRev = layout[1], layout[2]
                ns.Refresh()
                -- the remaining self buff takes the first place, the blessing button follows
                -- without a gap
                local step = D.SIZE + D.GAP
                assert.are.equal(D.PAD, math.abs(select(4, other:GetPoint()) + select(5, other:GetPoint())))
                local b = ns.blessingButton
                assert.are.equal(D.PAD + step, math.abs(select(4, b:GetPoint()) + select(5, b:GetPoint())))
            end
            check(c[key], true)
            assert.is_true(button:IsShown())
        end)
    end

    it("colors each button's ants on its own", function()
        local ns, c = open()
        pickColor(c.auraColor[1], { 0, 1, 0, 1 })
        assert.are.same({ 0, 1, 0, 1 }, ns.auraButton.ants.vertexColor)
        local gold = ns.D.ANTS_COLOR
        assert.are.same({ gold.r, gold.g, gold.b, gold.a }, ns.furyButton.ants.vertexColor)
        pickColor(c.furyColor[1], { 0, 0, 1, 1 })
        assert.are.same({ 0, 0, 1, 1 }, ns.furyButton.ants.vertexColor)
        assert.are.same({ 0, 1, 0, 1 }, ns.auraButton.ants.vertexColor)
    end)

    it("colors the blessing and Salvation buttons' ants apart from the others", function()
        local ns, c = open()
        pickColor(c.blessingColors[1], { 0, 1, 0, 1 })
        assert.are.same({ 0, 1, 0, 1 }, ns.blessingButton.ants.vertexColor)
        local gold = ns.D.ANTS_COLOR
        for _, b in ipairs({ ns.auraButton, ns.furyButton, ns.salvationButton }) do
            assert.are.same({ gold.r, gold.g, gold.b, gold.a }, b.ants.vertexColor)
        end
        pickColor(c.salvationColors[1], { 1, 0, 0, 1 })
        assert.are.same({ 1, 0, 0, 1 }, ns.salvationButton.ants.vertexColor)
        assert.are.same({ 0, 1, 0, 1 }, ns.blessingButton.ants.vertexColor)
    end)

    it("runs the blessing button's glow at its own speed", function()
        local ns, c, db, D = open()
        local b = ns.blessingButton
        assert.is_true(b.ants:IsShown()) -- the paladin and the mage lack Might
        c.blessingSpeed:SetValue(5)
        assert.are.equal(5, db.blessingAntsSpeed)
        assert.are.equal(D.GLOW_DURATIONS[5], b.antsFlip:GetDuration())
        -- the aura button keeps the default speed
        assert.are.equal(D.GLOW_DURATIONS[3], ns.auraButton.antsFlip:GetDuration())
        c.salvationSpeed:SetValue(1)
        assert.are.equal(5, db.blessingAntsSpeed)
        assert.are.equal(D.GLOW_DURATIONS[5], b.antsFlip:GetDuration())
    end)

    it("hides the blessing and Salvation buttons with their toggles", function()
        local ns, c, db = open()
        check(c.showBlessing, false)
        assert.is_false(db.showBlessing)
        assert.is_false(ns.blessingButton:IsShown())
        check(c.showSalvation, false)
        assert.is_false(ns.salvationButton:IsShown())
    end)

    it("runs the glow at the speed set for the button, at once", function()
        local ns, c, db, D = open()
        local flip = ns.auraButton.antsFlip
        assert.are.equal(1, D.GLOW_DURATIONS[3]) -- the default is Blizzard's second
        assert.are.equal(D.GLOW_DURATIONS[3], flip:GetDuration())
        c.auraSpeed:SetValue(5)
        assert.are.equal(5, db.auraAntsSpeed)
        assert.are.equal(D.GLOW_DURATIONS[5], flip:GetDuration())
        c.auraSpeed:SetValue(1)
        assert.are.equal(D.GLOW_DURATIONS[1], flip:GetDuration())
        -- the other button keeps its own speed, 3
        assert.are.equal(3, db.furyAntsSpeed)
        assert.are.equal(D.GLOW_DURATIONS[3], ns.furyButton.antsFlip:GetDuration())
    end)

    -- Blizzard's proc loop, as Michel saw it in game (ruleset plan 2026-10-20-button-tips-glow)
    it("glows with the client's proc loop on every button, 1.4 times the button, tinted", function()
        local ns, _, db, D = open()
        for _, case in ipairs({ { ns.auraButton, "auraAntsColor" }, { ns.furyButton, "furyAntsColor" },
                                { ns.blessingButton, "blessingAntsColor" }, { ns.salvationButton, "salvationAntsColor" } }) do
            local b, key = case[1], case[2]
            assert.are.equal("UI-HUD-ActionBar-Proc-Loop-Flipbook", b.ants.atlas)
            assert.are.same({ b:GetWidth() * 1.4, b:GetHeight() * 1.4 }, { b.ants:GetWidth(), b.ants:GetHeight() })
            assert.are.same({ "CENTER" }, { b.ants:GetPoint() })
            assert.is_true(b.ants:IsDesaturated())
            local col = db[key]
            assert.are.same({ col.r, col.g, col.b, col.a }, b.ants.vertexColor)
            assert.are.equal("REPEAT", b.antsAnim.looping)
            local flip = b.antsFlip
            assert.are.same({ "FlipBook", 6, 5, 30 }, { flip.kind, flip.rows, flip.columns, flip.frames })
        end
        assert.is_nil(D.ANTS_TEX)
        assert.is_nil(D.ANTS_STEPS)
    end)

    it("shows the default speed in the value text", function()
        local ns, c = open()
        assert.are.equal("3 (" .. ns.L.DEFAULT .. ")", c.furySpeedText:GetText())
        c.furySpeed:SetValue(4)
        assert.are.equal("4", c.furySpeedText:GetText())
    end)

    it("colors the count of the blessing and Salvation buttons", function()
        local ns, c = open()
        pickColor(c.blessingColors[2], { 1, 0.5, 0, 1 })
        assert.are.same({ 1, 0.5, 0, 1 }, ns.blessingButton.count.textColor)
        assert.are.same({ 1, 0.5, 0, 1 }, ns.salvationButton.count.textColor)
    end)
end)

-- The flyout and its settings went with plan 2026-10-19-priorities: auras come from a list
describe("the Tracking page without flyouts", function()
    it("offers no flyout settings", function()
        local _, c = open()
        assert.is_nil(c.autoClose)
        assert.is_nil(c.autoCloseTime)
    end)
end)
