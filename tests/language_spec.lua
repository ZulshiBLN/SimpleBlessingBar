-- The runtime language switch: ns.SetL, ns.ApplyLanguage, ns.OnLanguageChanged (ruleset plan
-- 2026-10-18-settings-window, IMPLEMENTATION "Tests, by phase" 1). Texts come from Locales.lua.

local addon = require("addon")

local function text()
    return NEWOBJ("FontString")
end

describe("the language switch", function()
    it("re-renders every registered text, with its format arguments", function()
        local ns = addon.load("enUS")
        local plain, formatted = text(), text()
        ns.SetL(plain, "NOT_IN_COMBAT")
        ns.SetL(formatted, "LOADED", "1.2.3")
        assert.are.equal(ns.locales.enUS.NOT_IN_COMBAT, plain:GetText())

        ns.ApplyLanguage("deDE")
        assert.are.equal(ns.locales.deDE.NOT_IN_COMBAT, plain:GetText())
        assert.are.equal(ns.locales.deDE.LOADED:format("1.2.3"), formatted:GetText())
    end)

    it("runs the callbacks after a change, and nothing when the language stays", function()
        local ns = addon.load("enUS")
        local calls = 0
        ns.OnLanguageChanged(function() calls = calls + 1 end)
        ns.ApplyLanguage("enUS")
        assert.are.equal(0, calls)
        ns.ApplyLanguage("frFR")
        assert.are.equal(1, calls)
    end)

    it("takes a function as the text, for texts built from several keys", function()
        local ns = addon.load("enUS")
        local t = text()
        ns.SetL(t, function() return ns.L.NOT_IN_COMBAT .. "!" end)
        ns.ApplyLanguage("deDE")
        assert.are.equal(ns.locales.deDE.NOT_IN_COMBAT .. "!", t:GetText())
    end)

    it("applies the saved language at login, to chat messages as well", function()
        local ns = addon.load("enUS", { globalDB = { language = "deDE" } })
        FIRE("PLAYER_LOGIN")
        assert.are.equal("deDE", ns.GetLocaleCode())
        assert.is_truthy(CHAT[#CHAT]:find(ns.locales.deDE.LOADED:format(ns.VERSION), 1, true))
    end)
end)
