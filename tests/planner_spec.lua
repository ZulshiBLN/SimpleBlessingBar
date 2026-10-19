-- The planner: which blessing this paladin gives whom, Greater or normal, and who gets
-- Salvation or Revoke (ruleset plan 2026-10-19-blessing-core, IMPLEMENTATION "Tests, by
-- phase" 2).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K, W = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS, D.BLESSINGS.WISDOM

-- `world`: group, units; `know`: spell IDs this paladin knows; `symbols` in the bags
local function plan(world, know, symbols)
    local ns = addon.load("enUS", world)
    STATE.known = {}
    for _, id in ipairs(know) do STATE.known[id] = true end
    STATE.bags = { [D.SYMBOL_OF_KINGS] = symbols or 0 }
    FIRE("PLAYER_LOGIN")
    return ns.Blessings
end

-- Might ranks 1..n, Kings, Wisdom ranks 1..5, Salvation, Revoke
local function basics(n, extra)
    local list = { K.normal[1], D.SALVATION, D.REVOKE }
    for i = 1, n or 6 do list[#list + 1] = M.normal[i] end
    for i = 1, 5 do list[#list + 1] = W.normal[i] end
    for _, id in ipairs(extra or {}) do list[#list + 1] = id end
    return list
end

local function aura(id, mine) return { spellId = id, expirationTime = 3600, mine = mine } end

local function entries(queue)
    local out = {}
    for i, e in ipairs(queue) do out[i] = { e.spell, e.unit } end
    return out
end

-- A raid of `n` members of one class, each { role =, auras =, range = }
local function raid(class, members)
    local units = {}
    for i, m in ipairs(members) do
        units["raid" .. i] = { class = class, role = m.role, auras = m.auras, range = m.range, subgroup = 1 }
    end
    return { group = "raid", units = units }
end

describe("my blessing for a member", function()
    it("is the first known blessing of the class's list, alone", function()
        local B = plan({}, basics())
        assert.are.same({ { M.normal[6], "player" } }, entries((B.PlanBlessings())))
    end)

    -- Lists by class: a role no longer chooses (ruleset plan 2026-10-19-priorities)
    it("follows each member's class list, whatever his role", function()
        local B = plan({ group = "party", units = {
            party1 = { class = "WARRIOR", role = "TANK" }, party2 = { class = "PRIEST" }, party3 = { class = "HUNTER" } } },
            basics())
        assert.are.same({ { M.normal[6], "player" }, { M.normal[6], "party1" }, { W.normal[5], "party2" },
                          { K.normal[1], "party3" } }, entries((B.PlanBlessings())))
    end)

    it("skips what another paladin gave, in an equal or higher rank", function()
        local B = plan({ group = "party", units = { party1 = { class = "PRIEST", auras = { aura(W.normal[5]) } } } },
            basics())
        local q = B.PlanBlessings()
        assert.are.same({ K.normal[1], "party1" }, entries(q)[2])
    end)

    it("is done once my blessing of the chosen family is on the member", function()
        local B = plan({ group = "party", units = { party1 = { class = "WARRIOR", auras = { aura(M.normal[6], true) } } } },
            basics())
        assert.are.same({ { M.normal[6], "player" } }, entries((B.PlanBlessings())))
    end)

    -- A change of a list is cast at once (ruleset plan 2026-10-19-blessing-steering)
    it("replaces my blessing of another family than the chosen one", function()
        local B = plan({ group = "party", units = { party1 = { class = "WARRIOR", auras = { aura(K.normal[1], true) } } } },
            basics())
        assert.are.same({ M.normal[6], "party1" }, entries((B.PlanBlessings()))[2])
    end)

    it("moves on when another paladin overwrote mine", function()
        -- my Might was replaced by another's: Might is given, my slot is free
        local B = plan({ group = "party", units = { party1 = { class = "WARRIOR", auras = { aura(M.normal[6]) } } } },
            basics())
        assert.are.same({ K.normal[1], "party1" }, entries((B.PlanBlessings()))[2])
    end)

    it("leaves out a member out of range", function()
        local B = plan({ group = "party", units = { party1 = { class = "WARRIOR", range = false } } }, basics())
        assert.are.same({ { M.normal[6], "player" } }, entries((B.PlanBlessings())))
    end)

    it("never counts my Salvation as a blessing", function()
        local B = plan({ group = "party", units = { party1 = { class = "MAGE",
            auras = { aura(D.SALVATION, true), aura(D.MASS_SALVATION, true) } } } }, basics())
        assert.are.same({ W.normal[5], "party1" }, entries((B.PlanBlessings()))[2])
    end)
end)

describe("Greater or normal", function()
    it("takes the Greater form where it is stronger, alone too", function()
        -- Might ranks 1-5 and Greater rank 1, which equals rank 6
        local B = plan({}, basics(5, { M.greater[1] }), 1)
        local q, used = B.PlanBlessings()
        assert.are.same({ { M.greater[1], "player" } }, entries(q))
        assert.is_true(q[1].greater)
        assert.are.equal(1, used)
    end)

    it("takes the normal form where it is stronger, in a raid too", function()
        local B = plan(raid("WARRIOR", { {}, {}, {}, {} }), basics(7, { M.greater[1] }), 5)
        local q = B.PlanBlessings()
        assert.are.equal(4, #q)
        assert.are.equal(M.normal[7], q[1].spell)
    end)

    it("takes normal between equals alone", function()
        local B = plan({}, basics(6, { M.greater[1] }), 5)
        assert.are.same({ { M.normal[6], "player" } }, entries((B.PlanBlessings())))
    end)

    it("takes normal between equals in a party of five, all of one class", function()
        local units = {}
        for i = 1, 4 do units["party" .. i] = { class = "WARRIOR" } end
        local B = plan({ group = "party", units = units, class = "PALADIN" }, basics(6, { M.greater[1] }), 5)
        local q = B.PlanBlessings()
        assert.are.equal(5, #q)
        for _, e in ipairs(q) do assert.is_nil(e.greater) end
    end)

    it("takes normal between equals in a party, even with three of a class", function()
        local B = plan({ group = "party", units = { party1 = { class = "WARRIOR" }, party2 = { class = "WARRIOR" },
                                                    party3 = { class = "WARRIOR" } } },
            basics(6, { M.greater[1] }), 5)
        for _, e in ipairs((B.PlanBlessings())) do assert.is_nil(e.greater) end
    end)

    it("takes normal between equals in a raid below three, Greater from three", function()
        local B = plan(raid("WARRIOR", { {}, {} }), basics(6, { M.greater[1] }), 5)
        assert.are.same({ { M.normal[6], "raid1" }, { M.normal[6], "raid2" } }, entries((B.PlanBlessings())))
        B = plan(raid("WARRIOR", { {}, {}, {} }), basics(6, { M.greater[1] }), 5)
        assert.are.same({ { M.greater[1], "raid1" } }, entries((B.PlanBlessings())))
    end)

    it("falls back to normal without a Symbol", function()
        local B = plan(raid("WARRIOR", { {}, {}, {} }), basics(6, { M.greater[1] }), 0)
        local q = B.PlanBlessings()
        assert.are.equal(3, #q)
        assert.is_nil(q[1].greater)
    end)

    -- An exception: a member another paladin gave Might moves on to Kings
    it("gives a class one Greater family, the most chosen, and the others normal after it", function()
        local given = { auras = { aura(M.normal[6]) } }
        local B = plan(raid("WARRIOR", { given, given, given, {}, {}, {}, {} }), basics(6, { M.greater[1], K.greater[1] }), 5)
        local q = B.PlanBlessings()
        assert.are.same({ M.greater[1], "raid1" }, entries(q)[1])
        assert.are.same({ { K.normal[1], "raid1" }, { K.normal[1], "raid2" }, { K.normal[1], "raid3" } },
            { entries(q)[2], entries(q)[3], entries(q)[4] })
        assert.are.equal(4, #q)
    end)

    it("queues the exceptions, and no Greater again, after the Greater one landed", function()
        local gm = aura(M.greater[1], true)
        local function w(given)
            local auras = { { spellId = gm.spellId, expirationTime = 3600, mine = true } }
            if given then auras[2] = aura(M.normal[6]) end
            return { auras = auras }
        end
        local B = plan(raid("WARRIOR", { w(true), w(true), w(true), w(), w(), w(), w() }),
            basics(6, { M.greater[1], K.greater[1] }), 5)
        assert.are.same({ { K.normal[1], "raid1" }, { K.normal[1], "raid2" }, { K.normal[1], "raid3" } },
            entries((B.PlanBlessings())))
    end)

    it("does not repeat a Greater one for members out of range", function()
        local function w(range, mine)
            return { range = range, auras = mine and { aura(M.greater[1], true) } or nil }
        end
        local B = plan(raid("WARRIOR", { w(nil, true), w(nil, true), w(false), w(false), w(false) }),
            basics(6, { M.greater[1] }), 5)
        assert.are.same({}, entries((B.PlanBlessings())))
    end)

    it("counts Symbols across the queue", function()
        local units = {}
        for i = 1, 3 do units["raid" .. i] = { class = "WARRIOR" } end
        for i = 4, 6 do units["raid" .. i] = { class = "ROGUE" } end
        local B = plan({ group = "raid", units = units }, basics(6, { M.greater[1] }), 1)
        local q, used = B.PlanBlessings()
        assert.are.same({ M.greater[1], "raid1" }, entries(q)[1])
        assert.are.equal(4, #q) -- the rogues get normal Might: no Symbol left
        assert.are.equal(1, used)
    end)
end)

describe("Salvation", function()
    it("goes to every member but a tank", function()
        local B = plan({ group = "party", units = {
            party1 = { class = "WARRIOR", role = "TANK" }, party2 = { class = "MAGE" } } }, basics())
        assert.are.same({ { D.SALVATION, "player" }, { D.SALVATION, "party2" } }, entries(B.PlanSalvation()))
    end)

    it("is revoked from a tank who carries it from anyone, first", function()
        local B = plan({ group = "party", units = {
            party1 = { class = "WARRIOR", role = "TANK", auras = { aura(D.SALVATION) } }, party2 = { class = "MAGE" } } },
            basics())
        assert.are.same({ D.REVOKE, "party1" }, entries(B.PlanSalvation())[1])
    end)

    it("leaves a tank with it without Revoke learned", function()
        local know = { K.normal[1], D.SALVATION, M.normal[1] }
        local B = plan({ group = "party", units = {
            party1 = { class = "WARRIOR", role = "TANK", auras = { aura(D.SALVATION) } } } }, know)
        assert.are.same({ { D.SALVATION, "player" } }, entries(B.PlanSalvation()))
    end)

    it("is Mass Salvation in a raid from three non-tanks plus the class's tanks", function()
        local tank = { role = "TANK" }
        local know = basics(6, { D.MASS_SALVATION })
        local B = plan(raid("WARRIOR", { tank, {}, {}, {} }), know, 1)
        assert.are.same({ D.SALVATION, D.SALVATION, D.SALVATION }, { B.PlanSalvation()[1].spell,
            B.PlanSalvation()[2].spell, B.PlanSalvation()[3].spell }) -- 3 < 3 + 1: single
        B = plan(raid("WARRIOR", { tank, {}, {}, {}, {} }), know, 1)
        local q = B.PlanSalvation()
        assert.are.same({ { D.MASS_SALVATION, "raid2" } }, entries(q))
        assert.is_true(q[1].greater)
    end)

    it("stays single without Mass Salvation learned or without a Symbol left", function()
        local B = plan(raid("MAGE", { {}, {}, {} }), basics(), 5)
        assert.are.equal(3, #B.PlanSalvation())
        B = plan(raid("MAGE", { {}, {}, {} }), basics(6, { D.MASS_SALVATION }), 1)
        assert.are.equal(3, #B.PlanSalvation(1)) -- the blessing queue took the only Symbol
        assert.are.equal(1, #B.PlanSalvation(0))
    end)

    it("orders Mass Salvation, then Revoke, then single Salvation in group order", function()
        local units = {}
        for i = 1, 3 do units["raid" .. i] = { class = "MAGE" } end
        units.raid4 = { class = "WARRIOR", role = "TANK", auras = { aura(D.SALVATION) } }
        units.raid5 = { class = "ROGUE" }
        local B = plan({ group = "raid", units = units }, basics(6, { D.MASS_SALVATION }), 1)
        assert.are.same({ { D.MASS_SALVATION, "raid1" }, { D.REVOKE, "raid4" }, { D.SALVATION, "raid5" } },
            entries(B.PlanSalvation()))
    end)

    it("never replaces Mass Salvation with single Salvation", function()
        local B = plan(raid("MAGE", { { auras = { aura(D.MASS_SALVATION) } }, {}, {} }), basics())
        local q = B.PlanSalvation()
        assert.are.same({ { D.SALVATION, "raid2" }, { D.SALVATION, "raid3" } }, entries(q))
    end)

    it("counts only members in range for Mass Salvation", function()
        local out = { range = false }
        local B = plan(raid("MAGE", { {}, {}, out, out, out }), basics(6, { D.MASS_SALVATION }), 1)
        assert.are.same({ { D.SALVATION, "raid1" }, { D.SALVATION, "raid2" } }, entries(B.PlanSalvation()))
    end)

    it("does not repeat Mass Salvation for members out of range", function()
        local function m(range, has)
            return { range = range, auras = has and { aura(D.MASS_SALVATION, true) } or nil }
        end
        local B = plan(raid("MAGE", { m(nil, true), m(nil, true), m(false), m(false), m(false) }),
            basics(6, { D.MASS_SALVATION }), 1)
        assert.are.same({}, entries(B.PlanSalvation()))
    end)

    it("is nothing without Salvation learned", function()
        local B = plan({}, { M.normal[1] })
        assert.are.same({}, B.PlanSalvation())
    end)
end)
