-- A member's role set by hand: the right-click menu on the blessing button, the memory by
-- GUID and its end (ruleset plan 2026-10-19-blessing-steering, phase 1).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS

local function known(...)
    local set = {}
    for _, id in ipairs({ ... }) do set[id] = true end
    return set
end

-- A paladin knowing Might, Kings and Salvation; `world` as for addon.load
local function login(world)
    world = world or {}
    world.known = world.known or known(M.normal[1], K.normal[1], D.SALVATION)
    local ns = addon.load("enUS", world)
    FIRE("PLAYER_LOGIN")
    ns.Refresh()
    return ns, ns.blessingButton
end

local function rightClick(b)
    RUNCLICK(b, "RightButton", true)
    RUNCLICK(b, "RightButton", false)
end

local function texts(menu)
    local out = {}
    for i, e in ipairs(menu.entries) do out[i] = e.text end
    return out
end

-- The menu entry with this text
local function entry(text)
    for _, e in ipairs(STATE.menu.entries) do
        if e.text == text then return e end
    end
end

describe("the role menu", function()
    it("opens on the right button's release, for the player without a target", function()
        local ns, b = login()
        STATE.units.player.surname = "Keshmar" -- UnitName's second value on Forever
        RUNCLICK(b, "RightButton", true)
        assert.is_nil(STATE.menu)
        RUNCLICK(b, "RightButton", false)
        local L = ns.L
        assert.are.same({ L.ROLE_MENU, "player" }, STATE.menu.titles)
        assert.are.same({ L.ROLE_AUTO, L.ROLE_MELEE, L.ROLE_HEALER, L.ROLE_TANK }, texts(STATE.menu))
        assert.is_true(STATE.menu.entries[1].selected)
        assert.is_nil(b:GetAttribute("type2"))
        assert.are.same({}, STATE.errors)
    end)

    it("is for the target when it is a group member, else for the player", function()
        local ns, b = login({ group = "party", units = { party1 = { class = "WARRIOR", name = "Grom" } } })
        STATE.units.target = STATE.units.party1
        rightClick(b)
        assert.are.same({ ns.L.ROLE_MENU, "Grom" }, STATE.menu.titles)
        assert.are.same({ ns.L.ROLE_AUTO, ns.L.ROLE_MELEE, ns.L.ROLE_TANK }, texts(STATE.menu))
        STATE.units.target = { class = "MAGE", name = "Stranger" }
        rightClick(b)
        assert.are.same({ ns.L.ROLE_MENU, "player" }, STATE.menu.titles)
    end)

    it("opens nothing in combat", function()
        local _, b = login()
        STATE.combat = true
        rightClick(b)
        assert.is_nil(STATE.menu)
        assert.are.same({}, STATE.errors)
    end)
end)

describe("a role set by hand", function()
    it("makes a tank of the player: Kings, no Salvation, and the left click still casts", function()
        local ns, b = login()
        rightClick(b)
        entry(ns.L.ROLE_TANK).pick()
        assert.are.equal(K.normal[1], b:GetAttribute("spell1"))
        assert.is_nil(ns.salvationButton:GetAttribute("spell1"))
        RUNCLICK(b, "LeftButton", true)
        RUNCLICK(b, "LeftButton", false)
        assert.are.same({ { spell = K.normal[1], unit = "player" } }, STATE.casts)
        rightClick(b)
        assert.is_true(entry(ns.L.ROLE_TANK).selected)
        assert.are.same({}, STATE.errors)
    end)

    it("is undone by Automatic, at once over a blessing of mine of the old choice", function()
        local ns, b = login()
        rightClick(b)
        entry(ns.L.ROLE_TANK).pick()
        STATE.units.player.auras = { { spellId = K.normal[1], expirationTime = 3600, mine = true } }
        ns.Refresh()
        rightClick(b)
        entry(ns.L.ROLE_AUTO).pick()
        assert.are.equal(M.normal[1], b:GetAttribute("spell1"))
        assert.are.equal(D.SALVATION, ns.salvationButton:GetAttribute("spell1"))
    end)

    it("chosen as combat starts, applies when it ends", function()
        local ns, b = login()
        rightClick(b)
        STATE.combat = true
        entry(ns.L.ROLE_TANK).pick()
        assert.are.equal(M.normal[1], b:GetAttribute("spell1"))
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.are.equal(K.normal[1], b:GetAttribute("spell1"))
        assert.are.same({}, STATE.errors)
    end)

    it("counts only where the class can play it", function()
        local ns = login({ group = "party", units = { party1 = { class = "MAGE" } } })
        ns.Blessings.SetHandRole(UnitGUID("party1"), "TANK")
        assert.are.equal("CASTER", ns.Blessings.RoleOf("party1"))
    end)

    it("is ignored in demo mode", function()
        local ns, b = login()
        rightClick(b)
        entry(ns.L.ROLE_TANK).pick()
        SimpleBlessingBarDB.demo = true
        ns.Refresh()
        assert.are.equal(tostring(#D.CLASS_ORDER), ns.salvationButton.count:GetText())
    end)

    it("ends when the member leaves the group", function()
        local ns, b = login({ group = "party", units = { party1 = { class = "WARRIOR" } } })
        STATE.units.player.auras = { { spellId = M.normal[1], expirationTime = 3600, mine = true } }
        local grom = STATE.units.party1
        STATE.units.target = grom
        rightClick(b)
        entry(ns.L.ROLE_TANK).pick()
        assert.are.same({ K.normal[1], "party1" }, { b:GetAttribute("spell1"), b:GetAttribute("unit1") })
        STATE.units.party1 = nil
        FIRE("GROUP_ROSTER_UPDATE")
        RUNTIMERS()
        STATE.units.party1 = grom
        FIRE("GROUP_ROSTER_UPDATE")
        RUNTIMERS()
        assert.are.same({ M.normal[1], "party1" }, { b:GetAttribute("spell1"), b:GetAttribute("unit1") })
    end)
end)
