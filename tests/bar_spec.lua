-- Bar.lua: the blessing button's secure attributes, the refresh and its combat freeze, the
-- handle (ruleset plans 2026-10-18-class-blessing-bar, 2026-10-19-blessing-core). The mock
-- raises an error when a protected frame is changed in combat; specs check STATE.errors
-- stays empty.

local addon = require("addon")

local function known(...)
    local set = {}
    for _, id in ipairs({ ... }) do set[id] = true end
    return set
end

-- A logged-in addon. `world` as for addon.load.
local function login(world)
    local ns = addon.load("enUS", addon.mightFirst(world))
    FIRE("PLAYER_LOGIN")
    ns.Refresh()
    return ns, ns.D, ns.blessingButton
end

-- The handle as SimpleConjureBar's (ruleset plan 2026-10-18-bar-polish, IMPLEMENTATION
-- "Tests, by phase" 3)
describe("the handle", function()
    local function lines()
        local out = {}
        for _, l in ipairs(GameTooltip.lines) do out[#out + 1] = l[2] and (l[1] .. "|" .. l[2]) or l[1] end
        return out
    end

    it("names the lock state and its three clicks in a tooltip", function()
        local ns = login()
        local L = ns.L
        RUNSCRIPT(ns.handle, "OnEnter")
        assert.are.equal(ns.handle, GameTooltip.owner)
        assert.are.equal("ANCHOR_LEFT", GameTooltip.anchor)
        assert.are.equal("SmartBlessingBar", GameTooltip:GetText())
        assert.are.same({ L.TIP_UNLOCKED, " ", L.LEFTCLICK .. "|" .. L.MOVE, L.RIGHTCLICK .. "|" .. L.LOCK,
                          L.MIDDLECLICK .. "|" .. L.SETTINGS }, lines())
        assert.are.same({ 0.4, 0.8, 1 }, { unpack(GameTooltip.lines[1], 3, 5) })
        RUNSCRIPT(ns.handle, "OnLeave")
        assert.is_false(GameTooltip:IsShown())
    end)

    it("shows the new state at once after a right click", function()
        local ns = login()
        local L = ns.L
        RUNSCRIPT(ns.handle, "OnEnter")
        RUNSCRIPT(ns.handle, "OnMouseDown", "RightButton")
        assert.is_true(SmartBlessingBarDB.locked)
        assert.are.equal(L.TIP_LOCKED, GameTooltip.lines[1][1])
        assert.are.same({ 1, 0.3, 0.3 }, { unpack(GameTooltip.lines[1], 3, 5) })
        assert.are.equal(L.RIGHTCLICK .. "|" .. L.UNLOCK, lines()[4])
    end)

    it("opens and closes the settings on a middle click, locked too", function()
        local ns = login()
        local window = ns.UI.window
        RUNSCRIPT(ns.handle, "OnMouseDown", "MiddleButton")
        assert.is_true(window:IsShown())
        RUNSCRIPT(ns.handle, "OnMouseDown", "MiddleButton")
        assert.is_false(window:IsShown())
        SmartBlessingBarDB.locked = true
        RUNSCRIPT(ns.handle, "OnMouseDown", "MiddleButton")
        assert.is_true(window:IsShown())
        assert.is_false(ns.handle.moving == true)
    end)

    it("opens nothing on a middle click in combat, and says why", function()
        local ns = login()
        STATE.combat = true
        RUNSCRIPT(ns.handle, "OnMouseDown", "MiddleButton")
        assert.is_false(ns.UI.window:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.MENU_COMBAT, 1, true))
        assert.are.same({}, STATE.errors)
    end)
end)

describe("the blessing button", function()
    it("casts with the left button only, registered for key down and up", function()
        local _, D, b = login({ known = known(19740) })
        assert.are.same({ "spell", D.BLESSINGS.MIGHT.normal[1], "player" },
            { b:GetAttribute("type1"), b:GetAttribute("spell1"), b:GetAttribute("unit1") })
        assert.is_nil(b:GetAttribute("type"))
        assert.is_nil(b:GetAttribute("type2"))
        assert.are.same({ "AnyUp", "AnyDown" }, b.clicks)
        assert.are.same({}, STATE.errors)
    end)

    it("changes only after combat when the group changes in it", function()
        local _, D, b = login({ known = known(19740, 20217), group = "party", units = { party1 = { class = "MAGE" } } })
        STATE.units.player.auras = { { spellId = D.BLESSINGS.MIGHT.normal[1], expirationTime = 3600, mine = true } }
        TICK()
        assert.are.equal("party1", b:GetAttribute("unit1"))
        STATE.combat = true
        STATE.units.party1 = nil
        FIRE("GROUP_ROSTER_UPDATE")
        RUNTIMERS()
        TICK()
        assert.are.equal("party1", b:GetAttribute("unit1"))
        assert.are.same({}, STATE.errors)
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_nil(b:GetAttribute("unit1"))
    end)
end)

describe("the refresh", function()
    local function myMight(D) return { { spellId = D.BLESSINGS.MIGHT.normal[1], expirationTime = 3600, mine = true } } end

    it("follows auras, the roster and the ticker out of combat", function()
        local _, D, b = login({ known = known(19740) })
        assert.are.equal("1", b.count:GetText())

        STATE.units.player.auras = myMight(D)
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        assert.are.equal("", b.count:GetText())

        STATE.units.player.auras = {}
        TICK()
        assert.are.equal("1", b.count:GetText())

        STATE.group = "party"
        STATE.units.party1 = { class = "WARRIOR" }
        FIRE("GROUP_ROSTER_UPDATE")
        RUNTIMERS()
        assert.are.equal("2", b.count:GetText())
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
        assert.are.equal("LEFT", SmartBlessingBarDB.point)
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

-- A regression guard: the class buttons went with the blessing core plan's phase 4
describe("the bar's buttons", function()
    it("have no class button and no flyout, in a raid of every class", function()
        local units = {}
        local D = addon.load("enUS").D
        for i, class in ipairs(D.CLASS_ORDER) do units["raid" .. i] = { class = class, subgroup = 1 } end
        local ns = login({ group = "raid", units = units })
        for _, class in ipairs(D.CLASS_ORDER) do
            assert.is_nil(_G["SmartBlessingBarClass" .. class], class)
            assert.is_nil(_G["SmartBlessingBarFlyout" .. class], class)
        end
        -- the aura flyout went with ruleset plan 2026-10-19-priorities
        assert.is_nil(ns.flyouts)
        assert.is_nil(ns.header)
    end)
end)
