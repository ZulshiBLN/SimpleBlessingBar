-- Settings.lua: the window, its tabs, Escape and combat (ruleset plan 2026-10-18-settings-window,
-- IMPLEMENTATION "Tests, by phase" 2). Opening goes through /sbb.

local addon = require("addon")

local function login()
    local ns = addon.load("enUS")
    FIRE("PLAYER_LOGIN")
    return ns, ns.UI
end

local function sbb(msg) SlashCmdList.SIMPLEBLESSINGBAR(msg) end

describe("the settings window", function()
    it("opens and closes with /sbb, and closes with Escape", function()
        local _, UI = login()
        local window = UI.window
        assert.is_false(window:IsShown())
        sbb("")
        assert.is_true(window:IsShown())
        sbb("")
        assert.is_false(window:IsShown())
        local escape = false
        for _, name in ipairs(UISpecialFrames) do
            if name == window:GetName() then escape = true end
        end
        assert.is_true(escape)
    end)

    it("has its tabs in order, and a tab shows its page alone", function()
        local ns, UI = login()
        sbb("")
        local names = {}
        for i, tab in ipairs(UI.tabs) do names[i] = tab:GetText() end
        assert.are.same({ ns.L.TAB_GENERAL, ns.L.TAB_TRACKING, ns.L.TAB_SUPPLIES }, names)
        assert.is_true(UI.pages[1]:IsShown())
        RUNSCRIPT(UI.tabs[2], "OnClick")
        assert.is_false(UI.pages[1]:IsShown())
        assert.is_true(UI.pages[2]:IsShown())
    end)

    it("closes when combat starts, and opens again only if combat closed it", function()
        local _, UI = login()
        sbb("")
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        assert.is_false(UI.window:IsShown())
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_true(UI.window:IsShown())

        sbb("") -- closed by hand before the next fight
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_false(UI.window:IsShown())
    end)

    it("does not open in combat, and says why", function()
        local ns, UI = login()
        STATE.combat = true
        sbb("")
        assert.is_false(UI.window:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.MENU_COMBAT, 1, true))
        assert.are.same({}, STATE.errors)
    end)

    it("follows a language change in its tab texts", function()
        local ns, UI = login()
        sbb("")
        ns.ApplyLanguage("deDE")
        assert.are.equal(ns.locales.deDE.TAB_GENERAL, UI.tabs[1]:GetText())
    end)
end)
