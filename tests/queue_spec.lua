-- Queue.lua: the blessing and Salvation buttons cast the head of their queue; in combat it
-- stays as it was (ruleset plan 2026-10-19-blessing-core, IMPLEMENTATION "Tests, by phase" 3).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS

local function know(extra)
    local set = { [K.normal[1]] = true, [D.SALVATION] = true, [D.REVOKE] = true }
    for i = 1, 6 do set[M.normal[i]] = true end
    for _, id in ipairs(extra or {}) do set[id] = true end
    return set
end

local function login(world, extra, symbols)
    local ns = addon.load("enUS", world)
    STATE.known = know(extra)
    STATE.bags = { [D.SYMBOL_OF_KINGS] = symbols or 0 }
    FIRE("PLAYER_LOGIN")
    return ns, ns.blessingButton, ns.salvationButton, SimpleBlessingBarDB
end

local function aura(id, mine) return { spellId = id, expirationTime = 3600, mine = mine } end

local function head(b) return { b:GetAttribute("type1"), b:GetAttribute("spell1"), b:GetAttribute("unit1") } end

describe("the blessing and Salvation buttons", function()
    it("cast the head of their queue, with the count of casts left and the ants", function()
        local _, bless, salv = login({ group = "party", units = { party1 = { class = "MAGE" } } })
        assert.are.same({ "spell", M.normal[6], "player" }, head(bless))
        assert.are.equal("2", bless.count:GetText())
        assert.is_true(bless.ants:IsShown())
        assert.are.same({ "spell", D.SALVATION, "player" }, head(salv))
        assert.are.equal("2", salv.count:GetText())
    end)

    it("have nothing to cast, no count and no ants when the queue is empty", function()
        STATE.units = {}
        local _, bless = login({ units = { player = { class = "PALADIN", auras = { aura(M.normal[6], true) } } } })
        assert.are.same({}, head(bless))
        assert.are.equal("", bless.count:GetText())
        assert.is_false(bless.ants:IsShown())
        assert.is_true(bless.icon:IsDesaturated())
    end)

    it("cast on a left click only; the middle click is left free", function()
        local _, bless = login()
        RUNCLICK(bless, "MiddleButton", true)
        assert.are.same({}, STATE.casts)
        RUNCLICK(bless, "LeftButton", true)
        assert.are.same({ { spell = M.normal[6], unit = "player" } }, STATE.casts)
    end)

    it("keep their head through combat, with no error, and move on after it", function()
        local ns, bless = login({ group = "party", units = { party1 = { class = "MAGE" } } })
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        STATE.units.player.auras = { aura(M.normal[6], true) } -- the head landed in combat
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        TICK()
        assert.are.same({ "spell", M.normal[6], "player" }, head(bless))
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.are.same({ "spell", K.normal[1], "party1" }, head(bless))
        assert.are.same({}, STATE.errors)
        assert.is_truthy(ns)
    end)

    it("put no Greater entry first at combat start for a class with exceptions", function()
        local units = { raid1 = { class = "WARRIOR", role = "TANK" } }
        for i = 2, 4 do units["raid" .. i] = { class = "WARRIOR" } end
        local _, bless = login({ group = "raid", units = units }, { M.greater[1] }, 5)
        assert.are.equal(M.greater[1], bless:GetAttribute("spell1"))
        FIRE("PLAYER_REGEN_DISABLED")
        assert.are.same({ "spell", K.normal[1], "raid1" }, head(bless))
    end)

    it("put no Mass Salvation first at combat start for a class with tanks", function()
        local units = { raid1 = { class = "WARRIOR", role = "TANK" } }
        for i = 2, 5 do units["raid" .. i] = { class = "WARRIOR" } end
        local _, _, salv = login({ group = "raid", units = units }, { D.MASS_SALVATION }, 5)
        assert.are.equal(D.MASS_SALVATION, salv:GetAttribute("spell1"))
        FIRE("PLAYER_REGEN_DISABLED")
        assert.are.same({}, head(salv)) -- the only entry is held back
    end)

    it("show the Symbol count on the blessing button only while a Greater form is known", function()
        local _, bless = login(nil, nil, 7)
        assert.are.equal("", bless.symbols:GetText())
        _, bless = login(nil, { M.greater[1] }, 7)
        assert.are.equal("7", bless.symbols:GetText())
    end)

    it("are hidden by their toggles, leaving no gap", function()
        local ns, bless, salv, db = login()
        local step = D.SIZE + D.GAP
        db.showBlessing = false
        ns.Refresh()
        assert.is_false(bless:IsShown())
        assert.are.equal(D.PAD + 2 * step, select(4, salv:GetPoint()))
        db.showSalvation = false
        ns.Refresh()
        assert.is_false(salv:IsShown())
        assert.are.equal(D.PAD + 2 * step, select(4, ns.classButtons.PALADIN:GetPoint()))
    end)

    it("show the head's spell and target in the tooltip, or that nothing is left", function()
        local ns, bless = login()
        RUNSCRIPT(bless, "OnEnter")
        assert.are.equal(M.normal[6], GameTooltip.spell)
        STATE.units.player.auras = { aura(M.normal[6], true) }
        ns.Refresh()
        RUNSCRIPT(bless, "OnEnter")
        assert.are.equal(ns.L.BTN_BLESSINGS, GameTooltip:GetText())
        assert.are.equal(ns.L.QUEUE_EMPTY, GameTooltip.lines[1][1])
    end)
end)
