-- Demo mode: every spell known, every class planned with its default role and no auras, no
-- click casts, the chat says what would be cast (ruleset plans 2026-10-18-settings-window
-- and 2026-10-19-blessing-core).

local addon = require("addon")

-- A paladin alone, knowing nothing but Devotion Aura rank 1 - no Righteous Fury, no blessing,
-- no Salvation, no Symbol of Kings
local function login(world)
    local ns = addon.load("enUS", world)
    STATE.known = { [ns.D.AURAS.DEVOTION[1]] = true }
    FIRE("PLAYER_LOGIN")
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
    return { ns.auraButton, ns.furyButton, ns.blessingButton, ns.salvationButton }
end

describe("demo mode", function()
    it("plans a blessing and Salvation for every class, out of a group", function()
        local ns, db, D = login()
        demoOn(ns)
        assert.is_true(db.demo)
        assert.are.equal(tostring(#D.CLASS_ORDER), ns.blessingButton.count:GetText())
        assert.are.equal(tostring(#D.CLASS_ORDER), ns.salvationButton.count:GetText()) -- no class defaults to tank
        assert.are.equal(tostring(D.DEMO_SYMBOLS), ns.blessingButton.symbols:GetText())
        assert.are.same({}, STATE.errors)
    end)

    it("reads no auras: another paladin's blessing on the player changes nothing", function()
        local ns, _, D = login()
        local might = D.BLESSINGS.MIGHT.normal
        STATE.units.player.auras = { { spellId = might[#might], expirationTime = 3600 } }
        demoOn(ns)
        -- the warrior, first class, melee: Might first, as if nobody had given it
        assert.are.equal(might[#might], ns.blessingButton:GetAttribute("spell1"))
    end)

    it("gives no main button a secure action, but each keeps its spell", function()
        local ns = login()
        demoOn(ns)
        for _, b in ipairs(mainButtons(ns)) do
            assert.is_nil(b:GetAttribute("type1"), b:GetName())
            assert.is_truthy(b:GetAttribute("spell1"), b:GetName())
        end
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
        -- Righteous Fury and Salvation too, though not learned
        assert.are.equal(D.RIGHTEOUS_FURY, ns.furyButton:GetAttribute("spell1"))
        assert.are.equal(D.SALVATION, ns.salvationButton:GetAttribute("spell1"))
        assert.are.same({}, STATE.casts)
    end)

    it("names the spell in the addon's language when it differs from the client's", function()
        local ns = login()
        demoOn(ns)
        ns.ApplyLanguage("deDE")
        local de = ns.locales.deDE
        click(ns.salvationButton, "LeftButton")
        assert.is_truthy(CHAT[#CHAT]:find(de.DEMO_CAST:format(de.SALVATION), 1, true))
        click(ns.auraButton, "LeftButton")
        assert.is_truthy(CHAT[#CHAT]:find(de.DEMO_CAST:format(de.AURA_DEVOTION), 1, true))
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
        click(ns.auraButton, "RightButton")
        click(ns.flyouts.AURA.icons[2], "LeftButton")
        assert.is_nil(ns.auraButton:GetAttribute("type1"))
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
        assert.are.equal("", ns.blessingButton.count:GetText()) -- no blessing learned
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
