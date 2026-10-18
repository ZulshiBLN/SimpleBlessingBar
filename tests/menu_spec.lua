-- Menu.lua: the assignment menu on a class button's right click (ruleset plan
-- 2026-10-18-class-blessing-bar, IMPLEMENTATION "Tests, by phase" 3).

local addon = require("addon")

local function login(known)
    local ns = addon.load("enUS", { known = known })
    FIRE("PLAYER_LOGIN")
    return ns, ns.D, ns.classButtons.PALADIN
end

local function knownOf(D, ...)
    local set = {}
    for _, family in ipairs({ ... }) do set[D.BLESSINGS[family].normal[1]] = true end
    return set
end

-- Right click as the client delivers it: key down, then key up
local function rightClick(button)
    RUNSCRIPT(button, "OnClick", "RightButton", true)
    RUNSCRIPT(button, "OnClick", "RightButton", false)
end

describe("the assignment menu", function()
    it("opens once on right click and not on left click", function()
        local ns, D, b = login()
        STATE.known = knownOf(D, "MIGHT")
        -- Count the openings: one right click delivers key down and key up
        local opened, create = 0, MenuUtil.CreateContextMenu
        MenuUtil.CreateContextMenu = function(...)
            opened = opened + 1
            return create(...)
        end
        RUNSCRIPT(b, "OnClick", "LeftButton", true)
        RUNSCRIPT(b, "OnClick", "LeftButton", false)
        assert.are.equal(0, opened)
        rightClick(b)
        assert.are.equal(1, opened)
        assert.are.equal(b, STATE.menu.owner)
        assert.are.equal(ns.L.MENU_ASSIGN, STATE.menu.title)
    end)

    it("offers only the blessings the paladin knows, in menu order", function()
        local ns, D, b = login()
        STATE.known = knownOf(D, "KINGS", "MIGHT")
        rightClick(b)
        local texts = {}
        for _, radio in ipairs(STATE.menu.radios) do texts[#texts + 1] = radio.text end
        assert.are.same({ ns.BlessingName("MIGHT"), ns.BlessingName("KINGS") }, texts)
    end)

    it("saves the choice per class and puts it on the button", function()
        local _, D, b = login()
        STATE.known = knownOf(D, "MIGHT", "KINGS")
        rightClick(b)
        STATE.menu.radios[2].select()
        assert.are.equal("KINGS", SimpleBlessingBarDB.assign.PALADIN)
        assert.is_nil(SimpleBlessingBarDB.assign.WARRIOR)
        assert.are.equal(D.BLESSINGS.KINGS.normal[1], b:GetAttribute("spell1"))
        rightClick(b)
        assert.is_true(STATE.menu.radios[2].selected())
        assert.is_false(STATE.menu.radios[1].selected())
    end)

    it("takes a choice made in combat into effect after combat", function()
        local _, D, b = login()
        STATE.known = knownOf(D, "MIGHT", "KINGS")
        rightClick(b)
        STATE.menu.radios[1].select()
        STATE.combat = true
        rightClick(b)
        STATE.menu.radios[2].select()
        assert.are.equal("KINGS", SimpleBlessingBarDB.assign.PALADIN)
        assert.are.equal(D.BLESSINGS.MIGHT.normal[1], b:GetAttribute("spell1"))
        assert.are.same({}, STATE.errors)
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.are.equal(D.BLESSINGS.KINGS.normal[1], b:GetAttribute("spell1"))
    end)
end)

describe("ns.LocalName", function()
    it("returns the client's name when the languages match, the addon's own otherwise", function()
        local ns = addon.load("enUS")
        assert.are.equal("Client name", ns.LocalName("Client name", "BLESSING_MIGHT"))
        ns.SetLocale("deDE")
        assert.are.equal(ns.locales.deDE.BLESSING_MIGHT, ns.LocalName("Client name", "BLESSING_MIGHT"))
        assert.are.equal(ns.locales.deDE.BLESSING_MIGHT, ns.LocalName(nil, "BLESSING_MIGHT"))
    end)
end)
