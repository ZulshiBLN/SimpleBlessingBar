-- The skeleton's behaviour: paladin-only loading, the saved variables checked
-- at login, and the login line in the right language. Versions, the schema
-- version and the texts are read from the TOC, Data.lua and Locales.lua.

local addon = require("addon")

local function tocVersion()
    return addon.read(addon.NAME .. "/" .. addon.NAME .. ".toc"):match("\n## Version:%s*([^\r\n]-)%s*[\r\n]")
end

-- Every chat line that names the addon, as the player sees it.
local function addonLines()
    local lines = {}
    for _, line in ipairs(CHAT) do
        if line:find(addon.NAME, 1, true) then lines[#lines + 1] = line end
    end
    return lines
end

describe("login", function()
    it("greets a paladin once, with the TOC's version, in the client's language", function()
        local ns = addon.load("deDE")
        FIRE("PLAYER_LOGIN")
        assert.are.same({}, STATE.errors)
        local lines = addonLines()
        assert.are.equal(1, #lines)
        local expected = ns.locales.deDE.LOADED:format(tocVersion())
        assert.is_truthy(lines[1]:find(expected, 1, true), lines[1])
    end)

    it("loads nothing for every other class", function()
        local ns = addon.load("enUS", { class = "MAGE" })
        FIRE("PLAYER_LOGIN")
        assert.is_false(ns.enabled)
        assert.is_nil(ns.InitDB)
        assert.are.same({}, addonLines())
        assert.is_nil(SimpleBlessingBarDB)
    end)

    it("replaces damaged saved variables and stamps the schema version", function()
        local ns = addon.load("enUS", { db = "damaged", globalDB = 42 })
        FIRE("PLAYER_LOGIN")
        assert.are.same({}, STATE.errors)
        assert.is_table(SimpleBlessingBarDB)
        assert.is_table(SimpleBlessingBarGlobalDB)
        assert.are.equal(ns.D.DB_VERSION, SimpleBlessingBarDB.dbVersion)
    end)

    it("hands the checked settings to modules registered before and after login", function()
        local ns = addon.load("enUS")
        local before, after
        ns.OnDBReady(function(db) before = db end)
        FIRE("PLAYER_LOGIN")
        ns.OnDBReady(function(db) after = db end)
        assert.are.equal(SimpleBlessingBarDB, before)
        assert.are.equal(SimpleBlessingBarDB, after)
    end)

    it("greets in the saved language, and drops an unknown one", function()
        local ns = addon.load("enUS", { globalDB = { language = "frFR" } })
        FIRE("PLAYER_LOGIN")
        local expected = ns.locales.frFR.LOADED:format(tocVersion())
        assert.is_truthy(addonLines()[1]:find(expected, 1, true), addonLines()[1])

        ns = addon.load("deDE", { globalDB = { language = "xxXX" } })
        FIRE("PLAYER_LOGIN")
        assert.is_nil(SimpleBlessingBarGlobalDB.language)
        expected = ns.locales.deDE.LOADED:format(tocVersion())
        assert.is_truthy(addonLines()[1]:find(expected, 1, true), addonLines()[1])
    end)
end)
