-- Blessings.lua: rank and Greater choice, who lacks a blessing, the count and the target of
-- a class button (ruleset plan 2026-10-18-class-blessing-bar, IMPLEMENTATION "Definitions").
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

describe("the spell a class button casts", function()
    it("is the Greater Blessing only with a Symbol of Kings in the bags", function()
        local _, D, B = load()
        local might = D.BLESSINGS.MIGHT
        STATE.known = known(might.normal, first(might.greater, 1))
        local spell, greater = B.CastSpell("MIGHT")
        assert.are.equal(might.normal[#might.normal], spell)
        assert.is_false(greater)

        STATE.bags[D.SYMBOL_OF_KINGS] = 3
        spell, greater = B.CastSpell("MIGHT")
        assert.are.equal(might.greater[1], spell)
        assert.is_true(greater)
    end)

    it("is nothing for a blessing the paladin has not learned", function()
        local _, _, B = load()
        assert.is_nil(B.CastSpell("KINGS"))
        assert.is_false(B.ClassState("PALADIN", "KINGS").castable)
    end)
end)

describe("a class button", function()
    -- A party: the paladin, two warriors, a mage. Might rank 1 is known.
    local function party(units)
        local ns, D, B = load({
            group = "party",
            units = units,
        })
        STATE.known = known(first(D.BLESSINGS.MIGHT.normal, 1))
        return ns, D, B
    end

    it("counts the class members who lack this paladin's blessing, in any rank or form", function()
        local _, D, B = party({
            party1 = { class = "WARRIOR" },
            party2 = { class = "WARRIOR", auras = { { spellId = 0, mine = true } } },
            party3 = { class = "MAGE" },
        })
        local might = D.BLESSINGS.MIGHT
        assert.are.equal(2, B.ClassState("WARRIOR", "MIGHT").count)
        STATE.units.party1.auras = { { spellId = might.greater[2], expirationTime = 50, mine = true } }
        STATE.units.party2.auras = { { spellId = might.normal[4], expirationTime = 50, mine = true } }
        assert.are.equal(0, B.ClassState("WARRIOR", "MIGHT").count)
    end)

    it("ignores another paladin's blessing of the same kind", function()
        local _, D, B = party({
            party1 = { class = "WARRIOR" },
        })
        STATE.units.party1.auras = { { spellId = D.BLESSINGS.MIGHT.normal[1], expirationTime = 50, mine = false } }
        assert.are.equal(1, B.ClassState("WARRIOR", "MIGHT").count)
    end)

    it("does not count dead or offline members", function()
        local _, _, B = party({
            party1 = { class = "WARRIOR", dead = true },
            party2 = { class = "WARRIOR", connected = false },
            party3 = { class = "WARRIOR" },
        })
        local state = B.ClassState("WARRIOR", "MIGHT")
        assert.are.equal(1, state.count)
        assert.are.equal("party3", state.target)
    end)

    it("targets the first member lacking it who is in range", function()
        local _, _, B = party({
            party1 = { class = "WARRIOR", range = false },
            party2 = { class = "WARRIOR" },
        })
        local state = B.ClassState("WARRIOR", "MIGHT")
        assert.are.equal(2, state.count)
        assert.are.equal("party2", state.target)
    end)

    it("with nobody lacking it, targets the blessing that ends first", function()
        local _, D, B = party({
            party1 = { class = "WARRIOR" },
            party2 = { class = "WARRIOR" },
            party3 = { class = "WARRIOR", range = false },
        })
        local id = D.BLESSINGS.MIGHT.normal[1]
        STATE.units.party1.auras = { { spellId = id, expirationTime = 900, mine = true } }
        STATE.units.party2.auras = { { spellId = id, expirationTime = 300, mine = true } }
        STATE.units.party3.auras = { { spellId = id, expirationTime = 100, mine = true } }
        local state = B.ClassState("WARRIOR", "MIGHT")
        assert.are.equal(0, state.count)
        assert.are.equal("party2", state.target)
    end)

    it("has no target when nobody of the class is in range", function()
        local _, _, B = party({
            party1 = { class = "WARRIOR", range = false },
        })
        local state = B.ClassState("WARRIOR", "MIGHT")
        assert.are.equal(1, state.count)
        assert.is_nil(state.target)
    end)
end)

describe("Salvation", function()
    -- A raid: the paladin in subgroup 1 with one rogue; another rogue in subgroup 2.
    local function raid()
        local me = { class = "PALADIN", subgroup = 1 }
        local ns = addon.load("enUS", {
            group = "raid",
            units = {
                player = me, raid1 = me,
                raid2 = { class = "ROGUE", subgroup = 2 },
                raid3 = { class = "ROGUE", subgroup = 1 },
            },
        })
        STATE.known = known(ns.D.BLESSINGS.SALVATION.normal)
        return ns, ns.D, ns.Blessings
    end

    it("counts and targets only the paladin's own party", function()
        local _, _, B = raid()
        local state = B.ClassState("ROGUE", "SALVATION")
        assert.are.equal(1, state.count)
        assert.are.equal("raid3", state.target)
    end)

    it("as Mass Salvation reaches the whole class", function()
        local _, D, B = raid()
        STATE.known = known(D.BLESSINGS.SALVATION.normal, D.BLESSINGS.SALVATION.greater)
        STATE.bags[D.SYMBOL_OF_KINGS] = 1
        local state = B.ClassState("ROGUE", "SALVATION")
        assert.is_true(state.greater)
        assert.are.equal(2, state.count)
        assert.are.equal("raid2", state.target)
    end)
end)
