-- The key bindings (ruleset plan 2026-10-20-key-bindings). The buff key carries the left-click
-- action of the first switched-on, glowing aura, Fury or blessing button in the bar's order -
-- the blessing button's being the group's next blessing; Salvation never.

local addon = require("addon")

local D = addon.load("enUS").D
local M = D.BLESSINGS.MIGHT
local DEVOTION = D.AURAS.DEVOTION[1]

-- A tank paladin in a party of his own, knowing Devotion 1, Righteous Fury, Might 1 and
-- Salvation; `world` may add to it
local function login(world)
    world = world or {}
    world.group = "party"
    world.units = world.units or { player = { class = "PALADIN", role = "TANK" } }
    local ns = addon.load("enUS", addon.mightFirst(world))
    STATE.known = { [DEVOTION] = true, [D.RIGHTEOUS_FURY] = true, [M.normal[1]] = true, [D.SALVATION] = true }
    FIRE("PLAYER_LOGIN")
    return ns, ns.buffKey
end

local function action(b) return { b:GetAttribute("type1"), b:GetAttribute("spell1"), b:GetAttribute("unit1") } end
local function mine(id) return { spellId = id, expirationTime = 3600, mine = true } end
local function carry(ns, ...)
    STATE.units.player.auras = { ... }
    ns.Refresh()
end

describe("the buff key", function()
    it("carries the first glowing button's action, in the bar's order, then the next", function()
        local ns, key = login()
        assert.are.same({ "spell", DEVOTION, "player" }, action(key))
        carry(ns, mine(DEVOTION))
        assert.are.same({ "spell", D.RIGHTEOUS_FURY, "player" }, action(key))
        carry(ns, mine(DEVOTION), mine(D.RIGHTEOUS_FURY))
        assert.are.same(action(ns.blessingButton), action(key))
        assert.are.equal(M.normal[1], key:GetAttribute("spell1"))
        assert.are.same({}, STATE.errors)
    end)

    -- Not a tank: a tank gets no Salvation, so its button would not glow
    it("never carries Salvation, and nothing once none of the three glows", function()
        local ns, key = login({ units = { player = { class = "PALADIN" } } })
        carry(ns, mine(DEVOTION), mine(M.normal[1]))
        assert.are.equal(D.SALVATION, ns.salvationButton:GetAttribute("spell1"))
        assert.are.same({}, action(key))
    end)

    it("follows the bar's order and skips a switched-off button", function()
        local ns, key = login()
        SmartBlessingBarDB.order = { "BLESSING", "AURA", "FURY", "SALVATION" }
        ns.Refresh()
        assert.are.equal(M.normal[1], key:GetAttribute("spell1"))
        SmartBlessingBarDB.showBlessing = false
        ns.Refresh()
        assert.are.equal(DEVOTION, key:GetAttribute("spell1"))
    end)

    it("takes Fury only as tank", function()
        local ns, key = login({ units = { player = { class = "PALADIN" } } })
        carry(ns, mine(DEVOTION))
        assert.are.equal(M.normal[1], key:GetAttribute("spell1"))
    end)

    it("keeps its action in combat", function()
        local ns, key = login()
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        STATE.units.player.auras = { mine(DEVOTION) }
        FIRE("UNIT_AURA", "player")
        RUNTIMERS()
        TICK()
        assert.are.same({ "spell", DEVOTION, "player" }, action(key))
        assert.are.same({}, STATE.errors)
        assert.is_truthy(ns)
    end)

    it("has no action in demo mode, also while auras are secret, and a press prints once", function()
        local ns, key = login()
        assert.are.equal("spell", key:GetAttribute("type1"))
        STATE.aurasSecret = true
        SmartBlessingBarDB.demo = true
        ns.Refresh()
        assert.is_nil(key:GetAttribute("type1"))
        STATE.aurasSecret = false
        ns.Refresh()
        assert.is_nil(key:GetAttribute("type1"))
        local before = #CHAT
        RUNCLICK(key, "LeftButton", true)
        RUNCLICK(key, "LeftButton", false)
        assert.are.same({}, STATE.casts)
        assert.are.equal(before + 1, #CHAT)
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.DEMO, 1, true))
    end)

    it("is a secure action button registered for key down and up", function()
        local _, key = login()
        assert.are.equal("SecureActionButtonTemplate", key.template)
        assert.are.same({ "AnyUp", "AnyDown" }, key.clicks)
        assert.are.equal(key, _G.SmartBlessingBarBuffAll)
    end)
end)

-- The Buff & Run key is a binding of the blessing button's middle click itself (phase 1 in
-- game: it blesses and moves on, also with the button hidden)
describe("the Buff & Run key", function()
    it("works through the blessing button's middle click, also with the button hidden", function()
        local ns = login({ units = { player = { class = "PALADIN" }, target = { class = "MAGE" } } })
        STATE.friends = { { class = "ROGUE" } }
        SmartBlessingBarDB.showBlessing = false
        ns.Refresh()
        assert.is_false(ns.blessingButton:IsShown())
        RUNCLICK(ns.blessingButton, "MiddleButton", true)
        RUNCLICK(ns.blessingButton, "MiddleButton", false)
        assert.are.equal(1, #STATE.casts)
        assert.are.equal("target", STATE.casts[1].unit)
        assert.are.equal(1, STATE.targetedNext)
    end)
end)

describe("the Priorities key", function()
    it("toggles the window on the Priorities tab on its release, and refuses in combat", function()
        local ns = login()
        local key = _G.SmartBlessingBarPrioritiesKey
        assert.are.same({ "AnyUp" }, key.clicks)
        RUNCLICK(key, "LeftButton", false)
        assert.is_true(ns.SettingsPageShown("TAB_PRIORITIES"))
        RUNCLICK(key, "LeftButton", false)
        assert.is_false(ns.UI.window:IsShown())
        STATE.combat = true
        RUNCLICK(key, "LeftButton", false)
        assert.is_false(ns.UI.window:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.NOT_IN_COMBAT, 1, true))
    end)
end)

-- Bindings.xml and the labels the game's Key Bindings show
describe("the key bindings", function()
    local BINDINGS = {
        { "CLICK SmartBlessingBarBuffAll:LeftButton", "KEY_BUFF_ALL" },
        { "CLICK SmartBlessingBarBlessing:MiddleButton", "BUFF_RUN" },
        { "CLICK SmartBlessingBarPrioritiesKey:LeftButton", "SET_PRIORITIES" },
    }

    it("are exactly the three in Bindings.xml, under the addon's header", function()
        local xml = addon.read(addon.NAME .. "/Bindings.xml")
        local names = {}
        for name in xml:gmatch('<Binding name="([^"]+)"') do names[#names + 1] = name end
        assert.are.same({ BINDINGS[1][1], BINDINGS[2][1], BINDINGS[3][1] }, names)
        assert.is_truthy(xml:find('header="SMARTBLESSINGBAR"', 1, true))
        -- A section of their own (Michel), not the shared AddOns one
        local _, inSection = xml:gsub('category="BINDING_HEADER_SMARTBLESSINGBAR"', "")
        assert.are.equal(3, inSection)
        assert.is_nil(xml:find('category="ADDONS"', 1, true))
    end)

    it("carry the locale's texts for every class and follow a paladin's language switch", function()
        for _, class in ipairs({ "PALADIN", "MAGE" }) do
            local ns = addon.load("deDE", { class = class })
            assert.are.equal("SmartBlessingBar", BINDING_HEADER_SMARTBLESSINGBAR)
            for _, b in ipairs(BINDINGS) do
                assert.are.equal(ns.locales.deDE[b[2]], _G["BINDING_NAME_" .. b[1]], class .. " " .. b[2])
            end
        end
        local ns = addon.load("deDE")
        FIRE("PLAYER_LOGIN")
        ns.ApplyLanguage("frFR")
        for _, b in ipairs(BINDINGS) do
            assert.are.equal(ns.locales.frFR[b[2]], _G["BINDING_NAME_" .. b[1]], b[2])
        end
    end)

    -- code.md's list of globals, which luacheck cannot see in `_G["..."]` writes: the
    -- .luacheckrc names, the binding labels and frame names starting SmartBlessingBar
    it("leave no global outside the rule's list, for a paladin and another class", function()
        local config = { files = {} }
        local chunk = assert(loadfile(".luacheckrc"))
        setfenv(chunk, config)
        chunk()
        local allowed = {}
        for _, name in ipairs(config.globals) do allowed[name] = true end
        for _, class in ipairs({ "PALADIN", "MAGE" }) do
            addon.load("enUS", { class = class, recordGlobals = true })
            FIRE("PLAYER_LOGIN")
            local seen = 0
            for name in pairs(addon.written) do
                seen = seen + 1
                local ok = allowed[name] or name:match("^BINDING_NAME_CLICK SmartBlessingBar")
                assert.is_truthy(ok, class .. ": " .. tostring(name))
            end
            assert.is_true(seen > 0, class) -- the recording works: the binding names at least
        end
    end)
end)
