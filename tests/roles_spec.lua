-- Roles: the game's group role where the class can play it, else the class default (ruleset
-- plan 2026-10-19-blessing-core, IMPLEMENTATION "Tests, by phase" 1).

local addon = require("addon")

local function login(units)
    local ns = addon.load("enUS", { group = "party", units = units })
    FIRE("PLAYER_LOGIN")
    return ns.Blessings, ns.D
end

describe("a member's role", function()
    it("is the class's only role, whatever the game reports", function()
        local B = login({ party1 = { class = "ROGUE", role = "TANK" }, party2 = { class = "MAGE", role = "HEALER" },
                          party3 = { class = "HUNTER" } })
        assert.are.equal("MELEE", B.RoleOf("party1"))
        assert.are.equal("CASTER", B.RoleOf("party2"))
        assert.are.equal("RANGED", B.RoleOf("party3"))
    end)

    it("is the reported tank or healer role where the class can play it", function()
        local B = login({ party1 = { class = "WARRIOR", role = "TANK" }, party2 = { class = "DRUID", role = "HEALER" },
                          party3 = { class = "SHAMAN", role = "TANK" }, party4 = { class = "PRIEST", role = "TANK" } })
        assert.are.equal("TANK", B.RoleOf("party1"))
        assert.are.equal("HEALER", B.RoleOf("party2"))
        assert.are.equal("TANK", B.RoleOf("party3"))
        assert.are.equal("HEALER", B.RoleOf("party4")) -- a priest cannot tank: its default
    end)

    it("is the class's first damage role for a reported damage dealer", function()
        local B = login({ party1 = { class = "PALADIN", role = "DAMAGER" }, party2 = { class = "DRUID", role = "DAMAGER" },
                          party3 = { class = "PRIEST", role = "DAMAGER" } })
        assert.are.equal("MELEE", B.RoleOf("party1"))
        assert.are.equal("CASTER", B.RoleOf("party2"))
        assert.are.equal("CASTER", B.RoleOf("party3"))
    end)

    it("is the class default when the game reports none", function()
        local B, D = login({ party1 = { class = "WARRIOR" }, party2 = { class = "DRUID" }, party3 = { class = "SHAMAN" } })
        assert.are.equal(D.CLASS_ROLES.WARRIOR[1], B.RoleOf("party1"))
        assert.are.equal(D.CLASS_ROLES.DRUID[1], B.RoleOf("party2"))
        assert.are.equal(D.CLASS_ROLES.SHAMAN[1], B.RoleOf("party3"))
    end)

    it("has a list for every role, and every class has a role", function()
        local _, D = login({})
        for _, role in ipairs(D.ROLES) do assert.is_table(D.ROLE_LISTS[role], role) end
        for _, class in ipairs(D.CLASS_ORDER) do
            for _, role in ipairs(D.CLASS_ROLES[class]) do assert.is_table(D.ROLE_LISTS[role], class) end
        end
    end)
end)
