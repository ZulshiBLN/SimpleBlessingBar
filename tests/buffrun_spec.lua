-- Buff & Run: the blessing button's middle click blesses the current target as his class's
-- list wants, then targets the next friendly player (ruleset plan 2026-10-20-buff-and-run).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K, W = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS, D.BLESSINGS.WISDOM

-- A paladin alone knowing Might 1-6, Kings 1, Greater Kings 1 and Wisdom 1-5; `target` the
-- current target's record, `friends` the players /targetfriendplayer finds next
local function login(target, friends)
    local ns = addon.load("enUS")
    STATE.known = { [K.normal[1]] = true, [K.greater[1]] = true }
    for i = 1, 6 do STATE.known[M.normal[i]] = true end
    for i = 1, 5 do STATE.known[W.normal[i]] = true end
    STATE.units.target = target
    STATE.friends = friends or {}
    FIRE("PLAYER_LOGIN")
    ns.Refresh()
    return ns, ns.blessingButton
end

local function aura(id, opts)
    opts = opts or {}
    return { spellId = id, expirationTime = opts.expires or 3600, mine = opts.mine, source = opts.source }
end

-- One middle click as the mouse gives it: press and release
local function press(b)
    RUNCLICK(b, "MiddleButton", true)
    RUNCLICK(b, "MiddleButton", false)
end

describe("Buff & Run's choice", function()
    local function choice(target)
        local ns = login(target)
        return ns.Blessings.BuffRunSpell("target")
    end

    it("gives a friendly player the first family of his class's list, in a normal rank", function()
        assert.are.equal(W.normal[5], choice({ class = "MAGE" }))      -- Wisdom, Kings, Light, Might
        assert.are.equal(M.normal[6], choice({ class = "WARRIOR" }))   -- Might, Kings, Light
        assert.are.equal(K.normal[1], choice({ class = "WARRIOR",       -- not the Greater one
            auras = { aura(M.normal[6], { source = "party1" }) } }))
    end)

    it("gives nothing to one carrying any blessing of mine, also one running out", function()
        assert.is_nil(choice({ class = "MAGE", auras = { aura(M.normal[1], { mine = true }) } }))
        assert.is_nil(choice({ class = "MAGE", auras = { aura(K.greater[1], { mine = true }) } }))
        assert.is_nil(choice({ class = "MAGE", auras = { aura(W.normal[5], { mine = true, expires = 1 }) } }))
    end)

    it("is not stopped by my Salvation or my aura", function()
        assert.are.equal(W.normal[5], choice({ class = "MAGE",
            auras = { aura(D.SALVATION, { mine = true }), aura(D.AURAS.DEVOTION[1], { mine = true }) } }))
    end)

    it("gives nothing to a dead, hostile, non-player or out-of-range target, or none", function()
        assert.is_nil(choice({ class = "MAGE", dead = true }))
        assert.is_nil(choice({ class = "MAGE", hostile = true }))
        assert.is_nil(choice({ class = "MAGE", npc = true }))
        assert.is_nil(choice({ class = "MAGE", range = false }))
        assert.is_nil(choice(nil))
    end)

    it("skips what others gave in an equal or higher rank, overwrites a lower one", function()
        assert.are.equal(K.normal[1], choice({ class = "MAGE", auras = { aura(W.normal[5], { source = "x" }) } }))
        assert.are.equal(W.normal[5], choice({ class = "MAGE", auras = { aura(W.normal[1], { source = "x" }) } }))
        -- Wisdom, Kings and Might given, Light unknown: nothing left
        assert.is_nil(choice({ class = "MAGE", auras = { aura(W.normal[5]), aura(K.normal[1]), aura(M.normal[6]) } }))
    end)
end)

describe("Buff & Run's middle click", function()
    it("casts on the current target, then targets the next friendly player", function()
        local next = { class = "ROGUE" }
        local _, b = login({ class = "MAGE" }, { next })
        assert.are.equal("macro", b:GetAttribute("type3"))
        assert.are.equal("/click SmartBlessingBarBuffRun LeftButton 1\n/targetfriendplayer", b:GetAttribute("macrotext3"))
        press(b)
        assert.are.same({ { spell = W.normal[5], unit = "target" } }, STATE.casts)
        assert.are.equal(next, STATE.units.target)
        assert.are.equal(1, STATE.targetedNext)
        assert.are.same({}, STATE.errors)
    end)

    it("only moves on from a target that needs nothing", function()
        local _, b = login({ class = "MAGE", auras = { aura(M.normal[1], { mine = true }) } }, { { class = "ROGUE" } })
        press(b)
        assert.are.same({}, STATE.casts)
        assert.are.equal(1, STATE.targetedNext)
    end)

    it("does nothing at all during the global cooldown, and tries again after it", function()
        local _, b = login({ class = "MAGE" }, { { class = "ROGUE" } })
        STATE.gcd = true
        press(b)
        assert.are.same({}, STATE.casts)
        assert.is_nil(STATE.targetedNext)
        STATE.gcd = false
        press(b)
        assert.are.equal(1, #STATE.casts)
        assert.are.equal(1, STATE.targetedNext)
    end)

    it("only moves on in combat, also after a cooldown press just before it", function()
        local _, b = login({ class = "MAGE" }, { { class = "ROGUE" }, { class = "PRIEST" } })
        STATE.gcd = true
        press(b) -- clears the macro for this press
        STATE.gcd = false
        FIRE("PLAYER_REGEN_DISABLED")
        STATE.combat = true
        press(b)
        assert.are.same({}, STATE.casts)
        assert.are.equal(1, STATE.targetedNext)
        assert.are.same({}, STATE.errors)
    end)

    it("leaves no spell from before combat for a click in it", function()
        local _, b = login({ class = "MAGE" }, { { class = "ROGUE" }, { class = "PRIEST" } })
        press(b) -- blesses the mage; the release already chose for the rogue
        assert.are.equal(1, #STATE.casts)
        FIRE("PLAYER_REGEN_DISABLED")
        STATE.combat = true
        press(b)
        assert.are.equal(1, #STATE.casts)
        assert.are.equal(2, STATE.targetedNext)
    end)

    it("casts nothing in demo mode, moves on and names what it would cast once", function()
        local ns, b = login({ class = "MAGE" }, { { class = "ROGUE" } })
        SmartBlessingBarDB.demo = true
        ns.Refresh()
        local before = #CHAT
        press(b)
        assert.are.same({}, STATE.casts)
        assert.are.equal(1, STATE.targetedNext)
        assert.are.equal(before + 1, #CHAT)
        -- demo mode treats every rank as known: the best one
        local best = W.normal[#W.normal]
        assert.is_truthy(CHAT[#CHAT]:find(ns.LocalName(C_Spell.GetSpellName(best), "BLESSING_WISDOM"), 1, true))
    end)
end)

-- The switch on the General tab, the tooltip line and settings version 9 (ruleset plan
-- 2026-10-20-buff-and-run, phase 4)
describe("Buff & Run's switch and tooltip", function()
    local function general(ns)
        SlashCmdList.SMARTBLESSINGBAR("")
        for i, page in ipairs(ns.UI.pages) do
            if page.titleKey == "TAB_GENERAL" then RUNSCRIPT(ns.UI.tabs[i], "OnClick") end
        end
        return ns.UI.controls.buffRun
    end

    local function tip(b)
        RUNSCRIPT(b, "OnEnter")
        local out = {}
        for i, l in ipairs(GameTooltip.lines) do out[i] = { l[1], l[2] } end
        return out
    end

    it("is on by default; switched off, the middle click does nothing", function()
        local ns, b = login({ class = "MAGE" }, { { class = "ROGUE" } })
        assert.is_true(SmartBlessingBarDB.buffRun)
        local check = general(ns)
        assert.is_true(check:GetChecked())
        check:SetChecked(false)
        RUNSCRIPT(check, "OnClick")
        assert.is_false(SmartBlessingBarDB.buffRun)
        assert.is_nil(b:GetAttribute("type3"))
        press(b)
        assert.are.same({}, STATE.casts)
        assert.is_nil(STATE.targetedNext)
        assert.is_nil(b:GetAttribute("type3")) -- the click does not set it again
        check:SetChecked(true)
        RUNSCRIPT(check, "OnClick")
        press(b)
        assert.are.equal(1, #STATE.casts)
    end)

    it("is not switched in combat, and says so", function()
        local ns = login({ class = "MAGE" })
        local check = general(ns)
        STATE.combat = true
        check:SetChecked(false)
        RUNSCRIPT(check, "OnClick")
        assert.is_true(SmartBlessingBarDB.buffRun)
        assert.is_true(check:GetChecked())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.NOT_IN_COMBAT, 1, true))
    end)

    it("names the middle click in the blessing tooltip while switched on", function()
        local ns, b = login({ class = "MAGE" })
        local L = ns.L
        local lines = tip(b)
        assert.are.same({ L.MIDDLECLICK, L.BUFF_RUN }, lines[#lines - 1])
        assert.are.same({ L.RIGHTCLICK, L.SET_PRIORITIES }, lines[#lines])
        SmartBlessingBarDB.buffRun = false
        ns.Refresh()
        lines = tip(b)
        assert.are.same({ L.RIGHTCLICK, L.SET_PRIORITIES }, lines[#lines])
        for _, l in ipairs(lines) do assert.are_not.equal(L.MIDDLECLICK, l[1]) end
    end)

    it("is added on by settings version 9, a saved choice kept", function()
        local ns = addon.load("enUS", { db = { dbVersion = 8 } })
        ns.InitDB()
        assert.are.equal(9, SmartBlessingBarDB.dbVersion)
        assert.is_true(SmartBlessingBarDB.buffRun)
        ns = addon.load("enUS", { db = { dbVersion = 9, buffRun = false } })
        ns.InitDB()
        assert.is_false(SmartBlessingBarDB.buffRun)
    end)
end)
