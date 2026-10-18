-- Demo mode: every spell known, every class shown with sample counts, no click casts, the
-- chat says what would be cast (ruleset plan 2026-10-18-settings-window, IMPLEMENTATION
-- "Tests, by phase" 5).

local addon = require("addon")

-- A paladin alone, knowing nothing but Devotion Aura rank 1 - and no Righteous Fury, no
-- blessing, no Symbol of Kings. Every class is assigned Blessing of Might.
local function login(world)
    local ns = addon.load("enUS", world)
    STATE.known = { [ns.D.AURAS.DEVOTION[1]] = true }
    FIRE("PLAYER_LOGIN")
    for _, class in ipairs(ns.D.CLASS_ORDER) do SimpleBlessingBarDB.assign[class] = "MIGHT" end
    return ns, SimpleBlessingBarDB, ns.D
end

local function demoOn(ns)
    SlashCmdList.SIMPLEBLESSINGBAR("")
    local cb = ns.UI.controls.demo
    cb:SetChecked(true)
    RUNSCRIPT(cb, "OnClick")
end

local function click(frame, mouseButton)
    RUNCLICK(frame, mouseButton, true)
    RUNCLICK(frame, mouseButton, false)
end

local function mainButtons(ns)
    local list = { ns.auraButton, ns.furyButton }
    for _, class in ipairs(ns.D.CLASS_ORDER) do list[#list + 1] = ns.classButtons[class] end
    return list
end

describe("demo mode", function()
    it("shows all nine class buttons with the sample counts, out of a group", function()
        local ns, db, D = login()
        demoOn(ns)
        assert.is_true(db.demo)
        for _, class in ipairs(D.CLASS_ORDER) do
            local b = ns.classButtons[class]
            assert.is_true(b:IsShown(), class)
            local n = D.DEMO_COUNTS[class]
            assert.are.equal(n > 0 and tostring(n) or "", b.count:GetText(), class)
        end
        assert.are.same({}, STATE.errors)
    end)

    it("gives no main button a secure action, but each keeps its spell", function()
        local ns = login()
        demoOn(ns)
        for _, b in ipairs(mainButtons(ns)) do
            assert.is_nil(b:GetAttribute("type1"), b:GetName())
            assert.is_truthy(b:GetAttribute("spell1"), b:GetName())
        end
    end)

    it("shows the Greater Blessing at its highest rank with no Symbol in the bags", function()
        local ns, _, D = login()
        demoOn(ns)
        local greater = D.BLESSINGS.MIGHT.greater
        assert.are.equal(greater[#greater], ns.classButtons.WARRIOR:GetAttribute("spell1"))
    end)

    it("prints what each main button would cast on a left click, and casts nothing", function()
        local ns, _, D = login()
        demoOn(ns)
        for _, b in ipairs(mainButtons(ns)) do
            local before = #CHAT
            click(b, "LeftButton")
            assert.are.equal(before + 1, #CHAT, b:GetName())
            local name = "spell" .. b:GetAttribute("spell1")
            assert.is_truthy(CHAT[#CHAT]:find(ns.L.DEMO_CAST:format(name), 1, true), b:GetName())
        end
        -- Righteous Fury too, though not learned
        assert.is_truthy(CHAT[#CHAT - 9]:find("spell" .. D.RIGHTEOUS_FURY, 1, true))
        assert.are.same({}, STATE.casts)
    end)

    it("names the spell in the addon's language when it differs from the client's", function()
        local ns = login()
        demoOn(ns)
        ns.ApplyLanguage("deDE")
        local de = ns.locales.deDE
        click(ns.auraButton, "LeftButton")
        assert.is_truthy(CHAT[#CHAT]:find(de.DEMO_CAST:format(de.AURA_DEVOTION), 1, true))
        click(ns.classButtons.MAGE, "LeftButton")
        local greater = de.DEMO_GREATER:format(de.BLESSING_MIGHT)
        assert.is_truthy(CHAT[#CHAT]:find(de.DEMO_CAST:format(greater), 1, true))
    end)

    it("prints nothing on a right click", function()
        local ns = login()
        demoOn(ns)
        local before = #CHAT
        for _, b in ipairs(mainButtons(ns)) do click(b, "RightButton") end
        assert.are.equal(before, #CHAT)
    end)

    it("sets no secure action through a flyout choice", function()
        local ns = login()
        demoOn(ns)
        local fly = ns.flyouts.WARRIOR
        click(ns.classButtons.WARRIOR, "RightButton")
        click(fly.icons[2], "LeftButton") -- Blessing of Wisdom
        assert.are.equal("WISDOM", SimpleBlessingBarDB.assign.WARRIOR)
        assert.is_nil(ns.classButtons.WARRIOR:GetAttribute("type1"))
        assert.are.same({}, STATE.casts)
        assert.are.same({}, STATE.errors)
    end)

    it("gives the bar back when switched off", function()
        local ns, db = login()
        demoOn(ns)
        local cb = ns.UI.controls.demo
        cb:SetChecked(false)
        RUNSCRIPT(cb, "OnClick")
        assert.is_false(db.demo)
        assert.is_false(ns.classButtons.WARRIOR:IsShown())
        assert.is_true(ns.classButtons.PALADIN:IsShown())
        assert.are.equal("spell", ns.auraButton:GetAttribute("type1"))
        assert.is_nil(ns.header:GetAttribute("demo"))
    end)

    it("is off after a reload", function()
        local _, db = login({ db = { demo = true } })
        assert.is_false(db.demo)
    end)

    it("cannot be switched in combat", function()
        local ns, db = login()
        SlashCmdList.SIMPLEBLESSINGBAR("")
        STATE.combat = true
        local cb = ns.UI.controls.demo
        cb:SetChecked(true)
        RUNSCRIPT(cb, "OnClick")
        assert.is_false(db.demo)
        assert.is_false(cb:GetChecked())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.NOT_IN_COMBAT, 1, true))
        assert.are.same({}, STATE.errors)
    end)
end)
