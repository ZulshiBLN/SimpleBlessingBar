-- The key bindings (ruleset plan 2026-10-20-key-bindings). The buff key carries the left-click
-- action of the first switched-on, glowing aura, Fury or blessing button in the bar's order -
-- the blessing button's being the group's next blessing; Salvation never.

local addon = require("addon")

local D = addon.load("enUS").D
local M = D.BLESSINGS.MIGHT
local DEVOTION = D.AURAS.DEVOTION[1]

-- A tank paladin in a party of his own, knowing Devotion 1, Righteous Fury, Might 1 and
-- Salvation; `world` may add to it
local function login(world)
    world = world or {}
    world.group = "party"
    world.units = world.units or { player = { class = "PALADIN", role = "TANK" } }
    local ns = addon.load("enUS", addon.mightFirst(world))
    STATE.known = { [DEVOTION] = true, [D.RIGHTEOUS_FURY] = true, [M.normal[1]] = true, [D.SALVATION] = true }
    FIRE("PLAYER_LOGIN")
    return ns, ns.buffKey
end

local function action(b) return { b:GetAttribute("type1"), b:GetAttribute("spell1"), b:GetAttribute("unit1") } end
local function mine(id) return { spellId = id, expirationTime = 3600, mine = true } end
local function carry(ns, ...)
    STATE.units.player.auras = { ... }
    ns.Refresh()
end

describe("the buff key", function()
    it("carries the first glowing button's action, in the bar's order, then the next", function()
        local ns, key = login()
        assert.are.same({ "spell", DEVOTION, "player" }, action(key))
        carry(ns, mine(DEVOTION))
        assert.are.same({ "spell", D.RIGHTEOUS_FURY, "player" }, action(key))
        carry(ns, mine(DEVOTION), mine(D.RIGHTEOUS_FURY))
        assert.are.same(action(ns.blessingButton), action(key))
        assert.are.equal(M.normal[1], key:GetAttribute("spell1"))
        assert.are.same({}, STATE.errors)
    end)

    -- Not a tank: a tank gets no Salvation, so its button would not glow
    it("never carries Salvation, and nothing once none of the three glows", function()
        local ns, key = login({ units = { player = { class = "PALADIN" } } })
        carry(ns, mine(DEVOTION), mine(M.normal[1]))
        assert.are.equal(D.SALVATION, ns.salvationButton:GetAttribute("spell1"))
        assert.are.same({}, action(key))
    end)

    it("follows the bar's order and skips a switched-off button", function()
        local ns, key = login()
        SmartBlessingBarDB.order = { "BLESSING", "AURA", "FURY", "SALVATION" }
        ns.Refresh()
        assert.are.equal(M.normal[1], key:GetAttribute("spell1"))
        SmartBlessingBarDB.showBlessing = false
        ns.Refresh()
        assert.are.equal(DEVOTION, key:GetAttribute("spell1"))
    end)

    it("takes Fury only as tank", function()
        local ns, key = login({ units = { player = { class = "PALADIN" } } })
        carry(ns, mine(DEVOTION))
        assert.are.equal(M.normal[1], key:GetAttribute("spell1"))
    end)

    it("keeps its action in combat", function()
        local ns, key = login()
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        STATE.units.player.auras = { mine(DEVOTION) }
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        TICK()
        assert.are.same({ "spell", DEVOTION, "player" }, action(key))
        assert.are.same({}, STATE.errors)
        assert.is_truthy(ns)
    end)

    it("has no action in demo mode, also while auras are secret, and a press prints once", function()
        local ns, key = login()
        assert.are.equal("spell", key:GetAttribute("type1"))
        STATE.aurasSecret = true
        SmartBlessingBarDB.demo = true
        ns.Refresh()
        assert.is_nil(key:GetAttribute("type1"))
        STATE.aurasSecret = false
        ns.Refresh()
        assert.is_nil(key:GetAttribute("type1"))
        local before = #CHAT
        RUNCLICK(key, "LeftButton", true)
        RUNCLICK(key, "LeftButton", false)
        assert.are.same({}, STATE.casts)
        assert.are.equal(before + 1, #CHAT)
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.DEMO, 1, true))
    end)

    it("is a secure action button registered for key down and up", function()
        local _, key = login()
        assert.are.equal("SecureActionButtonTemplate", key.template)
        assert.are.same({ "AnyUp", "AnyDown" }, key.clicks)
        assert.are.equal(key, _G.SmartBlessingBarBuffAll)
    end)
end)
