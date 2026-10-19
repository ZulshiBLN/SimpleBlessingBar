-- The pin "I give only X": it replaces every role list until logout (ruleset plan
-- 2026-10-19-blessing-steering, phase 3).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS

-- A paladin knowing Might and Kings; `world` as for addon.load
local function login(world)
    world = world or {}
    local ns = addon.load("enUS", world)
    STATE.known = { [M.normal[1]] = true, [K.normal[1]] = true }
    FIRE("PLAYER_LOGIN")
    ns.Refresh()
    SlashCmdList.SIMPLEBLESSINGBAR("") -- the dropdown is set up once the window shows
    return ns, ns.blessingButton
end

-- Picks an entry of the pin dropdown by its text
local function pin(ns, text)
    for _, e in ipairs(MENU(ns.UI.controls.pin)) do
        if e.text == text then e.pick() return end
    end
    error("no entry " .. tostring(text))
end

local function name(ns, family) return ns.Blessings.FamilyName(family) end

describe("the pin", function()
    it("offers None and the four blessings, None chosen", function()
        local ns = login()
        local entries = MENU(ns.UI.controls.pin)
        local texts = {}
        for i, e in ipairs(entries) do texts[i] = e.text end
        local expected = { ns.L.PIN_NONE }
        for _, family in ipairs(D.BLESSING_ORDER) do expected[#expected + 1] = name(ns, family) end
        assert.are.same(expected, texts)
        assert.is_true(entries[1].selected)
    end)

    it("replaces the role list: Kings pinned is offered to a melee", function()
        local ns, b = login()
        assert.are.equal(M.normal[1], b:GetAttribute("spell1"))
        pin(ns, name(ns, "KINGS"))
        assert.are.equal(K.normal[1], b:GetAttribute("spell1"))
        pin(ns, ns.L.PIN_NONE)
        assert.are.equal(M.normal[1], b:GetAttribute("spell1"))
    end)

    it("holds over a blessing switched off for the role", function()
        local ns, b = login({ db = { dbVersion = 7, roleLists = { MELEE = { order = { "KINGS", "LIGHT", "WISDOM" }, off = { MIGHT = true } } } } })
        assert.are.equal(K.normal[1], b:GetAttribute("spell1"))
        pin(ns, name(ns, "MIGHT"))
        assert.are.equal(M.normal[1], b:GetAttribute("spell1"))
    end)

    it("gives nothing where another paladin gave it, or no rank fits", function()
        local ns, b = login({ group = "party", units = {
            party1 = { class = "WARRIOR", auras = { { spellId = K.normal[1], expirationTime = 3600 } } },
            party2 = { class = "WARRIOR", level = 1 } } })
        STATE.learned = { [K.normal[1]] = 20 }
        STATE.units.player.auras = { { spellId = K.normal[1], expirationTime = 3600, mine = true } }
        pin(ns, name(ns, "KINGS"))
        assert.is_nil(b:GetAttribute("spell1"))
        assert.are.equal("", b.count:GetText())
    end)

    it("is named in the blessing button's tooltip while set", function()
        local ns, b = login()
        local function lines()
            RUNSCRIPT(b, "OnEnter")
            local out = {}
            for _, l in ipairs(GameTooltip.lines) do out[#out + 1] = l[1] end
            return table.concat(out, "|")
        end
        assert.is_nil(lines():find(ns.L.PIN_TOOLTIP:format(name(ns, "KINGS")), 1, true))
        pin(ns, name(ns, "KINGS"))
        assert.is_truthy(lines():find(ns.L.PIN_TOOLTIP:format(name(ns, "KINGS")), 1, true))
        assert.are.same({}, STATE.errors)
    end)

    it("is gone after a reload, and never saved", function()
        local ns = login()
        pin(ns, name(ns, "KINGS"))
        for _, v in pairs(SimpleBlessingBarDB) do assert.are_not.equal("KINGS", v) end
        local again, b = login({ db = SimpleBlessingBarDB })
        assert.are.equal(M.normal[1], b:GetAttribute("spell1"))
        assert.is_true(MENU(again.UI.controls.pin)[1].selected)
    end)
end)
