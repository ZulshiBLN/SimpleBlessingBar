-- The level fit: the game refuses a rank on a target more than ten levels below the level
-- the rank is learned at, so the planner offers only what fits (ruleset plan
-- 2026-10-19-rank-by-target-level).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K, W = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS, D.BLESSINGS.WISDOM

-- `world`: group, units; `know`: spell IDs this paladin knows; `learned`: spell ID -> the
-- level the game says it is learned at; `symbols` in the bags
local function plan(world, know, learned, symbols)
    local ns = addon.load("enUS", world)
    STATE.known = {}
    for _, id in ipairs(know) do STATE.known[id] = true end
    STATE.learned = learned
    STATE.bags = { [D.SYMBOL_OF_KINGS] = symbols or 0 }
    FIRE("PLAYER_LOGIN")
    return ns.Blessings, ns
end

-- Might ranks 1..6, Kings, Wisdom ranks 1..5, Salvation, Revoke, and `extra`
local function basics(extra)
    local list = { K.normal[1], D.SALVATION, D.REVOKE }
    for i = 1, 6 do list[#list + 1] = M.normal[i] end
    for i = 1, 5 do list[#list + 1] = W.normal[i] end
    for _, id in ipairs(extra or {}) do list[#list + 1] = id end
    return list
end

-- Wisdom learned at 14, 24, 34, 44, 54, as in Classic
local function wisdomLevels(t)
    t = t or {}
    for i, level in ipairs({ 14, 24, 34, 44, 54 }) do t[W.normal[i]] = level end
    return t
end

local function aura(id, mine) return { spellId = id, expirationTime = 3600, mine = mine } end

local function entries(queue)
    local out = {}
    for i, e in ipairs(queue) do out[i] = { e.spell, e.unit } end
    return out
end

local function party1(record)
    return { group = "party", units = { party1 = record } }
end

-- A raid of one class, each member { role =, level =, auras = }
local function raid(class, members)
    local units = {}
    for i, m in ipairs(members) do
        units["raid" .. i] = { class = class, role = m.role, level = m.level, auras = m.auras, subgroup = 1 }
    end
    return { group = "raid", units = units }
end

describe("a normal blessing", function()
    it("is the highest known rank that fits the target", function()
        -- rank 2 is learned at 24 and needs a target from 14
        local B = plan(party1({ class = "PRIEST", role = "HEALER", level = 13 }), basics(), wisdomLevels())
        assert.are.same({ W.normal[1], "party1" }, entries((B.PlanBlessings()))[2])
    end)

    it("counts another paladin's rank as given when it is my best that fits", function()
        local B = plan(party1({ class = "PRIEST", level = 13, auras = { aura(W.normal[1]) } }), basics(), wisdomLevels())
        assert.are.same({ K.normal[1], "party1" }, entries((B.PlanBlessings()))[2])
    end)

    it("still counts a lower rank than my best that fits as missing", function()
        -- rank 2 fits from 14, rank 3 from 24
        local B = plan(party1({ class = "PRIEST", level = 23, auras = { aura(W.normal[1]) } }), basics(), wisdomLevels())
        assert.are.same({ W.normal[2], "party1" }, entries((B.PlanBlessings()))[2])
    end)

    it("moves on to the next family when no rank of the first fits", function()
        local B = plan(party1({ class = "PRIEST", level = 3 }), basics(), wisdomLevels())
        assert.are.same({ K.normal[1], "party1" }, entries((B.PlanBlessings()))[2])
    end)

    it("is nothing for a member no blessing fits", function()
        local learned = wisdomLevels({ [K.normal[1]] = 20 })
        for i = 1, 6 do learned[M.normal[i]] = 4 + 8 * i end
        local world = party1({ class = "PRIEST", level = 1 })
        world.units.player = { class = "PALADIN", level = 60 }
        local B = plan(world, basics(), learned)
        assert.are.same({ { M.normal[6], "player" } }, entries((B.PlanBlessings())))
    end)

    -- Regression guards: they pass before and after the fit
    it("sets no limit for a level the game does not give", function()
        local B = plan(party1({ class = "PRIEST", level = 0 }), basics(), wisdomLevels())
        assert.are.same({ W.normal[5], "party1" }, entries((B.PlanBlessings()))[2])
        B = plan(party1({ class = "PRIEST", level = 13 }), basics())
        assert.are.same({ W.normal[5], "party1" }, entries((B.PlanBlessings()))[2])
    end)

    it("sets no limit in demo mode", function()
        -- every known spell learned at 60: without demo mode nothing would fit a level-1 player
        local learned = {}
        for _, id in ipairs(basics()) do learned[id] = 60 end
        local B = plan({ units = { player = { class = "PALADIN", level = 1 } } }, basics(), learned)
        SimpleBlessingBarDB.demo = true
        assert.are.equal(#D.CLASS_ORDER, #B.PlanBlessings())
    end)
end)

describe("a Greater Blessing", function()
    local learned = { [M.greater[1]] = 52 } -- fits from 42

    it("counts and targets only members it fits; the others get a normal one after it", function()
        local B = plan(raid("WARRIOR", { { level = 30 }, { level = 60 }, { level = 60 }, { level = 60 } }),
            basics({ M.greater[1] }), learned, 5)
        assert.are.same({ { M.greater[1], "raid2" }, { M.normal[6], "raid1" } }, entries((B.PlanBlessings())))
    end)

    it("is not cast for fewer than three members it fits", function()
        local B = plan(raid("WARRIOR", { { level = 30 }, { level = 60 }, { level = 60 } }),
            basics({ M.greater[1] }), learned, 5)
        local q = B.PlanBlessings()
        assert.are.equal(3, #q)
        for _, e in ipairs(q) do assert.is_nil(e.greater) end
    end)

    it("is not held back by an exception it does not fit", function()
        local B = plan(raid("WARRIOR", { { level = 60 }, { level = 60 }, { level = 60 }, { role = "TANK", level = 30 } }),
            basics({ M.greater[1] }), learned, 5)
        local q = B.PlanBlessings()
        assert.is_true(q[1].greater)
        assert.is_false(q[1].hold)
    end)
end)

describe("Salvation", function()
    it("leaves out a member it does not fit", function()
        local B = plan(party1({ class = "MAGE", level = 13 }), basics(), { [D.SALVATION] = 26 })
        assert.are.same({ { D.SALVATION, "player" } }, entries(B.PlanSalvation()))
    end)

    it("is no Revoke for a tank Revoke does not fit", function()
        local B = plan(party1({ class = "WARRIOR", role = "TANK", level = 5, auras = { aura(D.SALVATION) } }),
            basics(), { [D.REVOKE] = 20 })
        assert.are.same({ { D.SALVATION, "player" } }, entries(B.PlanSalvation()))
    end)

    it("is Mass Salvation counting and targeting only members it fits; the others get single", function()
        local B = plan(raid("MAGE", { { level = 30 }, { level = 60 }, { level = 60 }, { level = 60 } }),
            basics({ D.MASS_SALVATION }), { [D.MASS_SALVATION] = 60 }, 1)
        assert.are.same({ { D.MASS_SALVATION, "raid2" }, { D.SALVATION, "raid1" } }, entries(B.PlanSalvation()))
    end)

    it("counts and holds only for tanks Mass Salvation fits", function()
        local B = plan(raid("WARRIOR", { { role = "TANK", level = 30 }, { level = 60 }, { level = 60 }, { level = 60 } }),
            basics({ D.MASS_SALVATION }), { [D.MASS_SALVATION] = 60 }, 1)
        local q = B.PlanSalvation()
        assert.are.same({ { D.MASS_SALVATION, "raid2" } }, entries(q))
        assert.is_false(q[1].hold)
    end)
end)
