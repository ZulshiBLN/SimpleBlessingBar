-- Blessings.lua: the rank to cast, the planner's members and the use of a Symbol of Kings
-- (ruleset plans 2026-10-18-class-blessing-bar and 2026-10-19-blessing-core).
-- IDs come from Data.lua, never retyped.

local addon = require("addon")

-- A loaded addon in the given world; returns ns, its Data and the Blessings module.
local function load(world)
    local ns = addon.load("enUS", world)
    return ns, ns.D, ns.Blessings
end

-- The set of spell IDs IsPlayerSpell answers true for
local function known(...)
    local set = {}
    for _, list in ipairs({ ... }) do
        for _, id in ipairs(list) do set[id] = true end
    end
    return set
end

local function first(list, n)
    local out = {}
    for i = 1, n do out[i] = list[i] end
    return out
end

describe("rank", function()
    it("takes the highest known rank by rank order, not by ID", function()
        local ns = addon.load("enUS")
        local devotion = ns.D.AURAS.DEVOTION
        -- the premise that makes this test able to fail: rank 2 has the larger ID
        assert.is_true(devotion[2] > devotion[3])
        STATE.known = known(first(devotion, 3))
        assert.are.equal(devotion[3], ns.Blessings.Rank(devotion))
    end)

    it("returns nothing when no rank is known", function()
        local ns = addon.load("enUS")
        assert.is_nil(ns.Blessings.Rank(ns.D.AURAS.DEVOTION))
    end)
end)

describe("the planner's members", function()
    it("leave out dead and offline members", function()
        local ns, D, B = load({ group = "party", units = {
            party1 = { class = "WARRIOR", dead = true },
            party2 = { class = "WARRIOR", connected = false },
            party3 = { class = "WARRIOR" },
        } })
        STATE.known = known(first(D.BLESSINGS.MIGHT.normal, 1))
        FIRE("PLAYER_LOGIN")
        local units = {}
        for _, e in ipairs((B.PlanBlessings())) do units[#units + 1] = e.unit end
        assert.are.same({ "player", "party3" }, units)
        assert.is_truthy(ns)
    end)
end)

describe("a Symbol of Kings", function()
    it("is of use with a Greater Blessing or Mass Salvation known, not without", function()
        local _, D, B = load()
        STATE.known = known(D.BLESSINGS.MIGHT.normal)
        assert.is_false(B.AnyGreaterKnown())
        STATE.known = known({ D.MASS_SALVATION })
        assert.is_true(B.AnyGreaterKnown())
        STATE.known = known({ D.BLESSINGS.KINGS.greater[1] })
        assert.is_true(B.AnyGreaterKnown())
    end)
end)
