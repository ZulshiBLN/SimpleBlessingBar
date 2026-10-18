-- SelfBuffs.lua: the aura and Righteous Fury buttons (ruleset plan
-- 2026-10-18-class-blessing-bar, IMPLEMENTATION "Tests, by phase" 4).

local addon = require("addon")

local function login(known)
    local ns = addon.load("enUS", { known = known or {} })
    FIRE("PLAYER_LOGIN")
    return ns, ns.D
end

local function first(list, n)
    local set = {}
    for i = 1, n do set[list[i]] = true end
    return set
end

local function rightClick(button)
    RUNSCRIPT(button, "OnClick", "RightButton", true)
    RUNSCRIPT(button, "OnClick", "RightButton", false)
end

describe("the aura button", function()
    it("casts the highest known rank of the chosen aura with the left button only", function()
        local ns = addon.load("enUS")
        local list = ns.D.AURAS[ns.D.DEFAULT_AURA]
        STATE.known = first(list, 3)
        FIRE("PLAYER_LOGIN")
        local b = ns.auraButton
        assert.are.equal("spell", b:GetAttribute("type1"))
        assert.are.equal(list[3], b:GetAttribute("spell1"))
        assert.are.equal("player", b:GetAttribute("unit1"))
        assert.is_nil(b:GetAttribute("type"))
        assert.is_nil(b:GetAttribute("type2"))
        assert.are.same({ "AnyUp", "AnyDown" }, b.clicks)
    end)

    it("has no action and is greyed while the chosen aura is not known", function()
        local ns = login()
        assert.is_nil(ns.auraButton:GetAttribute("type1"))
        assert.is_true(ns.auraButton.icon:IsDesaturated())
    end)

    it("offers the known auras on right click and keeps the choice", function()
        local ns = addon.load("enUS")
        local D = ns.D
        STATE.known = first(D.AURAS.DEVOTION, 1)
        STATE.known[D.AURAS.RETRIBUTION[1]] = true
        FIRE("PLAYER_LOGIN")
        rightClick(ns.auraButton)
        assert.are.equal(ns.L.MENU_AURA, STATE.menu.title)
        local texts = {}
        for _, radio in ipairs(STATE.menu.radios) do texts[#texts + 1] = radio.text end
        assert.are.same({ ns.AuraName("DEVOTION"), ns.AuraName("RETRIBUTION") }, texts)
        STATE.menu.radios[2].select()
        assert.are.equal("RETRIBUTION", SimpleBlessingBarDB.aura)
        assert.are.equal(D.AURAS.RETRIBUTION[1], ns.auraButton:GetAttribute("spell1"))
    end)
end)

describe("the Righteous Fury button", function()
    it("casts Righteous Fury with the left button only", function()
        local ns = addon.load("enUS")
        STATE.known[ns.D.RIGHTEOUS_FURY] = true
        FIRE("PLAYER_LOGIN")
        local b = ns.furyButton
        assert.are.equal(ns.D.RIGHTEOUS_FURY, b:GetAttribute("spell1"))
        assert.are.equal("spell", b:GetAttribute("type1"))
        assert.is_nil(b:GetAttribute("type"))
        assert.are.same({ "AnyUp", "AnyDown" }, b.clicks)
    end)

    it("is highlighted while it is missing out of combat, and frozen in combat", function()
        local ns = addon.load("enUS")
        local rf = ns.D.RIGHTEOUS_FURY
        STATE.known[rf] = true
        FIRE("PLAYER_LOGIN")
        local glow = ns.furyButton.glow
        assert.is_true(glow:IsShown())

        STATE.units.player.auras = { { spellId = rf, expirationTime = 1800, mine = true } }
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        assert.is_false(glow:IsShown())

        STATE.combat = true
        STATE.units.player.auras = {}
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        TICK()
        assert.is_false(glow:IsShown())
        assert.are.same({}, STATE.errors)

        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_true(glow:IsShown())
    end)

    it("is not highlighted and has no action while it is not learned", function()
        local ns = login()
        assert.is_false(ns.furyButton.glow:IsShown())
        assert.is_nil(ns.furyButton:GetAttribute("type1"))
    end)
end)
