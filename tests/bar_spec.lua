-- Bar.lua: class buttons, their secure attributes, the refresh and its combat freeze, the
-- handle (ruleset plan 2026-10-18-class-blessing-bar, IMPLEMENTATION "Tests, by phase" 2).
-- The mock raises an error when a protected frame is changed in combat; specs check
-- STATE.errors stays empty.

local addon = require("addon")

local function known(...)
    local set = {}
    for _, id in ipairs({ ... }) do set[id] = true end
    return set
end

-- A logged-in addon. `world` as for addon.load; `assign` sets assignments after login.
local function login(world, assign)
    local ns = addon.load("enUS", world)
    FIRE("PLAYER_LOGIN")
    for class, family in pairs(assign or {}) do SimpleBlessingBarDB.assign[class] = family end
    ns.Refresh()
    return ns, ns.D, ns.classButtons
end

-- Ants on class buttons (ruleset plan 2026-10-18-bar-polish, IMPLEMENTATION "Tests, by phase" 2)
describe("a class button's ants", function()
    local function mine(D) return { { spellId = D.BLESSINGS.MIGHT.normal[1], expirationTime = 3600, mine = true } } end

    it("show while members lack the blessing, and stop at 0", function()
        local _, D, buttons = login({ known = known(19740) }, { PALADIN = "MIGHT" })
        local b = buttons.PALADIN
        assert.is_true(b.ants:IsShown())
        assert.is_truthy(b.antsHolder:GetScript("OnUpdate"))
        STATE.units.player.auras = mine(D)
        TICK()
        assert.are.equal("", b.count:GetText())
        assert.is_false(b.ants:IsShown())
        assert.is_nil(b.antsHolder:GetScript("OnUpdate"))
    end)

    it("do not show on a greyed button", function()
        local _, _, buttons = login({ known = known(19740) }, { PALADIN = "WISDOM" }) -- not learned
        assert.is_false(buttons.PALADIN.ants:IsShown())
        local _, _, none = login({ known = known(19740) }) -- nothing assigned
        assert.is_false(none.PALADIN.ants:IsShown())
    end)

    it("stop when the class leaves the group", function()
        local _, _, buttons = login({ known = known(19740), group = "party", units = { party1 = { class = "WARRIOR" } } },
            { WARRIOR = "MIGHT" })
        assert.is_true(buttons.WARRIOR.ants:IsShown())
        STATE.group, STATE.units.party1 = nil, nil
        TICK()
        assert.is_false(buttons.WARRIOR:IsShown())
        assert.is_nil(buttons.WARRIOR.antsHolder:GetScript("OnUpdate"))
    end)

    it("keep their state through combat and follow at its end", function()
        local _, D, buttons = login({ known = known(19740) }, { PALADIN = "MIGHT" })
        STATE.units.player.auras = mine(D)
        TICK()
        local b = buttons.PALADIN
        assert.is_false(b.ants:IsShown())
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        STATE.units.player.auras = {} -- the blessing runs out in combat
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        TICK()
        assert.is_false(b.ants:IsShown())
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_true(b.ants:IsShown())
        assert.are.same({}, STATE.errors)
    end)
end)

describe("a class button", function()
    it("casts with the left button only, registered for key down and up", function()
        local _, D, buttons = login({ known = known(19740) }, { PALADIN = "MIGHT" })
        local b = buttons.PALADIN
        assert.are.equal("spell", b:GetAttribute("type1"))
        assert.are.equal(D.BLESSINGS.MIGHT.normal[1], b:GetAttribute("spell1"))
        assert.are.equal("player", b:GetAttribute("unit1"))
        assert.is_nil(b:GetAttribute("type"))
        assert.is_nil(b:GetAttribute("type2"))
        assert.are.same({ "AnyUp", "AnyDown" }, b.clicks)
        assert.are.same({}, STATE.errors)
    end)

    it("has no secure action and is greyed without assignment, without the spell, or without a target", function()
        local _, _, unassigned = login({ known = known(19740) })
        assert.is_nil(unassigned.PALADIN:GetAttribute("type1"))
        assert.is_true(unassigned.PALADIN.classIcon:IsDesaturated())
        assert.are.equal("", unassigned.PALADIN.count:GetText())

        local _, _, unlearned = login({ known = known(19740) }, { PALADIN = "KINGS" })
        assert.is_nil(unlearned.PALADIN:GetAttribute("type1"))
        assert.is_true(unlearned.PALADIN.classIcon:IsDesaturated())

        local _, _, outOfRange = login({ group = "party", known = known(19740), units = {
            party1 = { class = "WARRIOR", range = false },
        } }, { WARRIOR = "MIGHT" })
        assert.is_nil(outOfRange.WARRIOR:GetAttribute("type1"))
        assert.is_false(outOfRange.WARRIOR.classIcon:IsDesaturated())
        assert.are.equal("1", outOfRange.WARRIOR.count:GetText())
    end)
end)

describe("the class buttons", function()
    it("appear for the classes in the group, in class order", function()
        local ns, D, buttons = login({ group = "party", units = {
            party1 = { class = "MAGE" },
            party2 = { class = "WARRIOR" },
        } })
        local shown = {}
        for _, class in ipairs(D.CLASS_ORDER) do
            if buttons[class]:IsShown() then
                shown[#shown + 1] = { class, select(4, buttons[class]:GetPoint()) }
            end
        end
        -- left to right in D.CLASS_ORDER: Warrior, Paladin, Mage
        assert.are.equal(3, #shown)
        local expect = {}
        for _, class in ipairs(D.CLASS_ORDER) do
            if class == "WARRIOR" or class == "PALADIN" or class == "MAGE" then expect[#expect + 1] = class end
        end
        for i, entry in ipairs(shown) do
            assert.are.equal(expect[i], entry[1])
            if i > 1 then assert.is_true(entry[2] > shown[i - 1][2]) end
        end
        assert.is_false(buttons.ROGUE:IsShown())
        assert.is_table(ns.bar)
    end)

    it("change only after combat when the group changes in it", function()
        local _, _, buttons = login({ group = "party", units = { party1 = { class = "MAGE" } } })
        assert.is_true(buttons.MAGE:IsShown())
        STATE.combat = true
        STATE.units.party1 = nil
        FIRE("GROUP_ROSTER_UPDATE")
        RUNTIMERS()
        TICK()
        assert.is_true(buttons.MAGE:IsShown())
        assert.are.same({}, STATE.errors)
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_false(buttons.MAGE:IsShown())
    end)
end)

describe("the refresh", function()
    local function myMight(D) return { { spellId = D.BLESSINGS.MIGHT.normal[1], expirationTime = 3600, mine = true } } end

    it("follows auras, the roster and the ticker out of combat", function()
        local _, D, buttons = login({ known = known(19740) }, { PALADIN = "MIGHT", WARRIOR = "MIGHT" })
        assert.are.equal("1", buttons.PALADIN.count:GetText())

        STATE.units.player.auras = myMight(D)
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        assert.are.equal("", buttons.PALADIN.count:GetText()) -- nobody lacks it: no 0

        STATE.units.player.auras = {}
        TICK()
        assert.are.equal("1", buttons.PALADIN.count:GetText())

        STATE.group = "party"
        STATE.units.party1 = { class = "WARRIOR" }
        FIRE("GROUP_ROSTER_UPDATE")
        RUNTIMERS()
        assert.is_true(buttons.WARRIOR:IsShown())
    end)

    it("leaves counts and actions alone in combat and catches up after it", function()
        local _, D, buttons = login({ known = known(19740) }, { PALADIN = "MIGHT" })
        local b = buttons.PALADIN
        STATE.known[D.BLESSINGS.WISDOM.normal[1]] = true
        STATE.combat = true
        STATE.units.player.auras = myMight(D)
        SimpleBlessingBarDB.assign.PALADIN = "WISDOM"
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        TICK()
        assert.are.equal("1", b.count:GetText())
        assert.are.equal(D.BLESSINGS.MIGHT.normal[1], b:GetAttribute("spell1"))
        assert.are.same({}, STATE.errors)

        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.are.equal(D.BLESSINGS.WISDOM.normal[1], b:GetAttribute("spell1"))
        assert.are.equal("1", b.count:GetText())
    end)
end)

describe("the handle", function()
    it("refuses to drag in combat, and saves the position after a drag", function()
        local ns = login()
        STATE.combat = true
        RUNSCRIPT(ns.handle, "OnMouseDown", "LeftButton")
        assert.is_not_true(ns.bar.moving)
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.NOT_IN_COMBAT, 1, true))

        STATE.combat = false
        RUNSCRIPT(ns.handle, "OnMouseDown", "LeftButton")
        assert.is_true(ns.bar.moving)
        RUNSCRIPT(ns.handle, "OnMouseUp", "LeftButton")
        assert.is_false(ns.bar.moving)
        assert.are.equal("LEFT", SimpleBlessingBarDB.point)
        assert.are.same({}, STATE.errors)
    end)

    it("does not drag a locked bar, and a saved position is restored at login", function()
        local ns = addon.load("enUS", { db = { dbVersion = 2, locked = true,
            point = "LEFT", rel = "BOTTOMLEFT", x = 300, y = 400 } })
        FIRE("PLAYER_LOGIN")
        RUNSCRIPT(ns.handle, "OnMouseDown", "LeftButton")
        assert.is_not_true(ns.bar.moving)
        assert.are.same({ "LEFT", UIParent, "BOTTOMLEFT", 300, 400 }, { ns.bar:GetPoint() })
    end)
end)
