-- Early renewal: an aura of mine running out within db.renewMinutes counts as missing, so it
-- is renewed before it is gone (ruleset plan 2026-10-19-blessing-steering, phase 4).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS

-- `world` as for addon.load; `know` spell IDs; `symbols` in the bags; `db` the saved file
local function plan(world, know, symbols)
    local ns = addon.load("enUS", world)
    STATE.known = {}
    for _, id in ipairs(know) do STATE.known[id] = true end
    STATE.bags = { [D.SYMBOL_OF_KINGS] = symbols or 0 }
    STATE.now = 10000
    FIRE("PLAYER_LOGIN")
    return ns.Blessings, ns, SimpleBlessingBarDB
end

local BASICS = { M.normal[1], K.normal[1], D.SALVATION, D.REVOKE }

-- An aura running out `minutes` from now (STATE.now = 10000)
local function aura(id, minutes, mine)
    return { spellId = id, expirationTime = 10000 + minutes * 60, mine = mine }
end

local function entries(queue)
    local out = {}
    for i, e in ipairs(queue) do out[i] = { e.spell, e.unit } end
    return out
end

local function alone(auras)
    return { units = { player = { class = "PALADIN", auras = auras } } }
end

describe("early renewal", function()
    it("offers my blessing again below the set minutes, not before", function()
        local B = plan(alone({ aura(M.normal[1], 4, true) }), BASICS)
        assert.are.same({ M.normal[1], "player" }, entries((B.PlanBlessings()))[1])
        B = plan(alone({ aura(M.normal[1], 6, true) }), BASICS)
        assert.are.same({}, entries((B.PlanBlessings())))
    end)

    it("follows the setting, and 0 renews only once it ran out", function()
        local B, _, db = plan(alone({ aura(M.normal[1], 10, true) }), BASICS)
        db.renewMinutes = 15
        assert.are.equal(1, #B.PlanBlessings())
        db.renewMinutes = 0
        STATE.units.player.auras = { aura(M.normal[1], 0.01, true) }
        assert.are.equal(0, #B.PlanBlessings())
    end)

    it("never renews an aura without expiry", function()
        local B = plan(alone({ { spellId = M.normal[1], expirationTime = 0, mine = true } }), BASICS)
        assert.are.equal(0, #B.PlanBlessings())
    end)

    it("leaves another paladin's blessing counted until it runs out", function()
        local B = plan(alone({ aura(M.normal[1], 1) }), BASICS)
        assert.are.same({ K.normal[1], "player" }, entries((B.PlanBlessings()))[1])
    end)

    it("renews my Greater Blessing for its class", function()
        local know = { M.greater[1], D.SALVATION }
        for i = 1, 6 do know[#know + 1] = M.normal[i] end
        local units = {}
        for i = 1, 3 do units["raid" .. i] = { class = "WARRIOR", subgroup = 1, auras = { aura(M.greater[1], 4, true) } } end
        local B = plan({ group = "raid", units = units }, know, 5)
        assert.are.same({ { M.greater[1], "raid1" } }, entries((B.PlanBlessings())))
    end)

    it("renews my Salvation on a non-tank, not another paladin's", function()
        local B = plan(alone({ aura(D.SALVATION, 4, true) }), BASICS)
        assert.are.same({ { D.SALVATION, "player" } }, entries(B.PlanSalvation()))
        B = plan(alone({ aura(D.SALVATION, 4) }), BASICS)
        assert.are.same({}, entries(B.PlanSalvation()))
    end)

    it("still revokes my Salvation running out on a tank", function()
        local B = plan({ group = "party", units = { party1 = { class = "WARRIOR", role = "TANK",
            auras = { aura(D.SALVATION, 4, true) } } } }, BASICS)
        assert.are.same({ D.REVOKE, "party1" }, entries(B.PlanSalvation())[1])
    end)

    it("renews my Mass Salvation for its class", function()
        local units = {}
        for i = 1, 3 do units["raid" .. i] = { class = "MAGE", subgroup = 1, auras = { aura(D.MASS_SALVATION, 4, true) } } end
        local B = plan({ group = "raid", units = units }, { D.SALVATION, D.MASS_SALVATION, M.normal[1] }, 1)
        assert.are.same({ { D.MASS_SALVATION, "raid1" } }, entries(B.PlanSalvation()))
    end)
end)

describe("the renewal setting", function()
    it("is 5 minutes by default, 0 to 15, and the button follows a change", function()
        local _, ns, db = plan(alone({ aura(M.normal[1], 10, true) }), BASICS)
        assert.are.equal(5, db.renewMinutes)
        ns.Refresh()
        assert.is_nil(ns.blessingButton:GetAttribute("spell1"))
        SlashCmdList.SIMPLEBLESSINGBAR("")
        ns.UI.controls.renewMinutes:SetValue(15)
        assert.are.equal(15, db.renewMinutes)
        assert.are.equal(M.normal[1], ns.blessingButton:GetAttribute("spell1"))
        local range = D.NUMBER_DEFAULTS.renewMinutes
        assert.are.same({ 0, 15, true }, { range.min, range.max, range.integer })
    end)
end)
