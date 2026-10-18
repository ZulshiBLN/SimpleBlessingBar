-- SelfBuffs.lua: the aura and Righteous Fury buttons (ruleset plans
-- 2026-10-18-class-blessing-bar phase 4, and 2026-10-18-flyouts phase 2 for the aura glow;
-- the aura flyout itself is in flyout_aura_spec).

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

local function refresh()
    FIRE("UNIT_AURA", "player")
    RUNTIMERS()
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

    it("glows while none of the paladin's own auras is up, whichever family", function()
        local ns, D = login()
        STATE.known = first(D.AURAS.DEVOTION, 1)
        STATE.known[D.AURAS.FIRE[1]] = true
        refresh()
        local glow = ns.auraButton.glow
        assert.is_true(glow:IsShown())

        STATE.units.player.auras = { { spellId = D.AURAS.FIRE[1], expirationTime = 0, mine = true } }
        refresh()
        assert.is_false(glow:IsShown())

        -- another paladin's aura on him does not count
        STATE.units.player.auras = { { spellId = D.AURAS.DEVOTION[1], expirationTime = 0, mine = false } }
        refresh()
        assert.is_true(glow:IsShown())
    end)

    it("does not glow while no aura is known, and keeps its glow in combat", function()
        local ns, D = login()
        assert.is_false(ns.auraButton.glow:IsShown())

        STATE.known = first(D.AURAS.DEVOTION, 1)
        refresh()
        assert.is_true(ns.auraButton.glow:IsShown())
        STATE.combat = true
        STATE.units.player.auras = { { spellId = D.AURAS.DEVOTION[1], expirationTime = 0, mine = true } }
        refresh()
        TICK()
        assert.is_true(ns.auraButton.glow:IsShown())
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_false(ns.auraButton.glow:IsShown())
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
