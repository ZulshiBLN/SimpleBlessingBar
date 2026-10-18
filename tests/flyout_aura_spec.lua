-- Flyout.lua with the aura button: open, close and auto-hide, the icons, selecting in and
-- out of combat (ruleset plan 2026-10-18-flyouts, IMPLEMENTATION "Tests, by phase" 2).
-- Clicks go through RUNCLICK, which runs the secure snippets as the client does.

local addon = require("addon")

-- A paladin who knows Devotion ranks 1-2 and Retribution rank 1
local function login()
    local ns = addon.load("enUS")
    local A = ns.D.AURAS
    STATE.known = { [A.DEVOTION[1]] = true, [A.DEVOTION[2]] = true, [A.RETRIBUTION[1]] = true }
    FIRE("PLAYER_LOGIN")
    return ns, ns.D, ns.flyouts.AURA
end

local function click(frame, mouseButton)
    RUNCLICK(frame, mouseButton, true)
    RUNCLICK(frame, mouseButton, false)
end

local function shownIcons(fly)
    local list = {}
    for _, icon in ipairs(fly.icons) do
        if icon:IsShown() then list[#list + 1] = icon end
    end
    return list
end

describe("the aura flyout", function()
    it("opens on one right click, closes on the next, and never casts from it", function()
        local ns, _, fly = login()
        assert.is_false(fly:IsShown())
        click(ns.auraButton, "RightButton")
        assert.is_true(fly:IsShown())
        click(ns.auraButton, "RightButton")
        assert.is_false(fly:IsShown())
        assert.are.equal(0, #STATE.casts)
    end)

    it("registers the auto-hide with its button when it opens, and drops it when it closes", function()
        local ns, D, fly = login()
        click(ns.auraButton, "RightButton")
        assert.are.equal(D.FLYOUT_AUTOHIDE, fly.autoHide)
        assert.are.same({ ns.auraButton }, fly.autoHideWith)
        click(ns.auraButton, "RightButton")
        assert.is_nil(fly.autoHide)
        assert.are.same({}, STATE.errors)
    end)

    it("stays closed on a left click, which casts the chosen aura", function()
        local ns, D, fly = login()
        click(ns.auraButton, "LeftButton")
        assert.is_false(fly:IsShown())
        assert.are.same({ { spell = D.AURAS.DEVOTION[2], unit = "player" } }, STATE.casts)
    end)

    it("offers the known auras at their highest rank, in order, with the client's tooltip", function()
        local _, D, fly = login()
        local icons = shownIcons(fly)
        assert.are.equal(2, #icons)
        assert.are.equal(D.AURAS.DEVOTION[2], icons[1]:GetAttribute("sbbspell"))
        assert.are.equal(D.AURAS.RETRIBUTION[1], icons[2]:GetAttribute("sbbspell"))
        -- an icon selects; it has no secure action of its own
        assert.is_nil(icons[1]:GetAttribute("type1"))
        assert.is_nil(icons[1]:GetAttribute("type"))
        RUNSCRIPT(icons[2], "OnEnter")
        assert.are.equal(D.AURAS.RETRIBUTION[1], GameTooltip.spell)
    end)

    it("selects an aura in combat without casting it, and the aura button casts it then", function()
        local ns, D, fly = login()
        STATE.combat = true
        click(ns.auraButton, "RightButton")
        click(shownIcons(fly)[2], "LeftButton")
        assert.are.equal(0, #STATE.casts)
        assert.is_false(fly:IsShown())
        assert.is_nil(fly.autoHide)
        assert.are.equal("RETRIBUTION", SimpleBlessingBarDB.aura)
        local ret = D.AURAS.RETRIBUTION[1]
        click(ns.auraButton, "LeftButton")
        assert.are.same({ { spell = ret, unit = "player" } }, STATE.casts)
        assert.are.same({}, STATE.errors)

        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.are.equal(ret, ns.auraButton:GetAttribute("spell1"))
    end)

    it("does nothing on a right click on an icon", function()
        local ns, _, fly = login()
        click(ns.auraButton, "RightButton")
        click(shownIcons(fly)[2], "RightButton")
        assert.are.equal(0, #STATE.casts)
        assert.are.equal("DEVOTION", SimpleBlessingBarDB.aura)
        assert.is_true(fly:IsShown())
    end)

    it("selects nothing on a press that is never released on the icon", function()
        local ns, D, fly = login()
        click(ns.auraButton, "RightButton")
        local icon = shownIcons(fly)[2]
        RUNCLICK(icon, "LeftButton", true)
        assert.are.equal("DEVOTION", SimpleBlessingBarDB.aura)
        assert.are.equal(D.AURAS.DEVOTION[2], ns.auraButton:GetAttribute("spell1"))
        assert.is_true(fly:IsShown())
        RUNCLICK(icon, "LeftButton", false)
        assert.are.equal("RETRIBUTION", SimpleBlessingBarDB.aura)
    end)
end)
