-- Presence: whether another paladin already gave a member a blessing, in its Greater form or
-- a rank at least this paladin's best (ruleset plan 2026-10-19-blessing-core, IMPLEMENTATION
-- "Tests, by phase" 1).

local addon = require("addon")

-- A paladin who knows Might ranks 1 to `ranks` (6 if not given); party1 is a warrior
-- carrying `auras`
local function login(auras, ranks)
    local ns = addon.load("enUS", { group = "party", units = { party1 = { class = "WARRIOR", auras = auras } } })
    local M = ns.D.BLESSINGS.MIGHT.normal
    STATE.known = {}
    for i = 1, ranks or 6 do STATE.known[M[i]] = true end
    FIRE("PLAYER_LOGIN")
    return ns.Blessings, ns.D
end

local function aura(id, mine) return { spellId = id, expirationTime = 3600, mine = mine } end

describe("a blessing given by others", function()
    it("counts in an equal or higher rank", function()
        local probe = addon.load("enUS")
        local M = probe.D.BLESSINGS.MIGHT.normal
        local B = login({ aura(M[6]) })
        assert.is_true(B.GivenByOthers("party1", "MIGHT"))
        B = login({ aura(M[7]) })
        assert.is_true(B.GivenByOthers("party1", "MIGHT"))
    end)

    it("does not count in a lower rank: casting it again is worth it", function()
        local probe = addon.load("enUS")
        local B = login({ aura(probe.D.BLESSINGS.MIGHT.normal[5]) })
        assert.is_false(B.GivenByOthers("party1", "MIGHT"))
    end)

    it("counts in its Greater form, even below this paladin's best rank", function()
        local probe = addon.load("enUS")
        -- Greater rank 1 equals rank 6; this paladin knows rank 7
        local B = login({ aura(probe.D.BLESSINGS.MIGHT.greater[1]) }, 7)
        assert.is_true(B.GivenByOthers("party1", "MIGHT"))
    end)

    it("does not count when it is this paladin's own", function()
        local probe = addon.load("enUS")
        local B = login({ aura(probe.D.BLESSINGS.MIGHT.normal[6], true) })
        assert.is_false(B.GivenByOthers("party1", "MIGHT"))
    end)

    it("is per family: another family does not count", function()
        local probe = addon.load("enUS")
        local B = login({ aura(probe.D.BLESSINGS.KINGS.normal[1]), aura(probe.D.BLESSINGS.WISDOM.greater[2]) })
        assert.is_false(B.GivenByOthers("party1", "MIGHT"))
        assert.is_true(B.GivenByOthers("party1", "KINGS")) -- Kings has one rank; none known counts too
    end)
end)

-- Read in game with C_Spell.GetSpellDescription (ruleset decisions 2026-10-19): each Greater
-- rank gives exactly what this normal rank gives - external facts, so spelled out here
local EQUAL = {
    [25782] = 19838, [25916] = 25291, -- Greater Might 1, 2 = Might 6 (112 AP), 7 (133 AP)
    [25894] = 19854, [25918] = 25290, -- Greater Wisdom 1, 2 = Wisdom 5 (36 mp5), 6 (40 mp5)
    [25890] = 19979,                  -- Greater Light = Light 3 (400 / 115)
    [25898] = 20217,                  -- Greater Kings = Kings
}

describe("a blessing's strength", function()
    it("equals a Greater rank with the normal rank of the same bonus", function()
        local R = addon.load("enUS").Blessings.RANKS
        for greater, normal in pairs(EQUAL) do
            assert.is_true(R[greater].greater, greater)
            assert.are.equal(R[normal].strength, R[greater].strength, greater)
        end
    end)
end)
