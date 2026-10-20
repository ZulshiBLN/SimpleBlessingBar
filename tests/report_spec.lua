-- Report.lua: the bug report window and its text (ruleset plan 2026-10-18-settings-more,
-- IMPLEMENTATION "Tests, by phase" 5). The mock's player is "Zulshe Keshmar" on "Forever".

local addon = require("addon")

local function login(world)
    local ns = addon.load("enUS", world)
    FIRE("PLAYER_LOGIN")
    return ns, SmartBlessingBarDB
end

local function err(message, stack, counter)
    return { message = message, stack = stack or "", counter = counter or 1, time = "2026/10/18 12:00:00" }
end

describe("the bug report", function()
    it("names the addon, client, language, character and settings", function()
        local ns, db = login()
        local text = ns.BuildReport("")
        assert.is_truthy(text:find("Addon version: " .. ns.VERSION, 1, true))
        assert.is_truthy(text:find("1.60.1 (build 70450, interface 16001)", 1, true))
        assert.is_truthy(text:find("Client locale: enUS, addon language: auto", 1, true))
        assert.is_truthy(text:find("Character: PALADIN, level 25, solo", 1, true))
        assert.is_truthy(text:find("scale=" .. tostring(db.scale), 1, true))
        assert.is_truthy(text:find("order=AURA,FURY,BLESSING,SALVATION", 1, true))
        assert.is_nil(text:find("classOrder", 1, true))
        assert.is_truthy(text:find("**Description:** -", 1, true))
        assert.is_truthy(text:find("none from SmartBlessingBar", 1, true))
    end)

    it("never names the player or the realm, also not from an error or the description", function()
        local ns = login()
        STATE.bugs = { err('SmartBlessingBar: error("SmartBlessingBar Zulshe")',
            "Interface/AddOns/SmartBlessingBar/Bar.lua:1: Keshmar on Forever") }
        local text = ns.BuildReport("Zulshe saw it")
        assert.is_nil(text:find("Zulshe", 1, true))
        assert.is_nil(text:find("Keshmar", 1, true))
        assert.is_nil(text:find("Forever", 1, true))
        assert.is_truthy(text:find("SmartBlessingBar <player>", 1, true))
        assert.is_truthy(text:find("<player> on <realm>", 1, true))
        assert.is_truthy(text:find("<player> saw it", 1, true))
    end)

    -- The client errors on comparing a secret value; the mock cannot, so the spec shows the
    -- secret name was never used: it is left as it stands
    it("touches no secret name", function()
        local ns = login()
        STATE.secretName = true
        STATE.bugs = { err("SmartBlessingBar Zulshe on Forever") }
        local text = ns.BuildReport("")
        assert.is_truthy(text:find("SmartBlessingBar Zulshe on <realm>", 1, true))
    end)

    it("takes only this addon's errors, the newest five, with at most 12 stack lines", function()
        local ns = login()
        local bugs = { err("OtherAddon broke") }
        for i = 1, 7 do bugs[#bugs + 1] = err("SmartBlessingBar error " .. i) end
        local long = {}
        for i = 1, 20 do long[i] = "line" .. i end
        bugs[#bugs + 1] = err("SmartBlessingBar error 8", table.concat(long, "\n"), 3)
        STATE.bugs = bugs
        local text = ns.BuildReport("")
        assert.is_nil(text:find("OtherAddon", 1, true))
        assert.is_truthy(text:find("Error 1 (x3", 1, true)) -- newest first
        assert.is_truthy(text:find("error 4", 1, true))
        assert.is_nil(text:find("error 3", 1, true))
        assert.is_truthy(text:find("line12\n...", 1, true))
        assert.is_nil(text:find("line13", 1, true))
    end)

    it("says when BugGrabber is not installed", function()
        local ns = login({ bugGrabber = false })
        assert.is_truthy(ns.BuildReport(""):find("BugGrabber/BugSack not installed", 1, true))
    end)
end)

describe("the bug report window", function()
    it("opens from /sbb bug and from General, and replaces the settings window", function()
        local ns = login()
        SlashCmdList.SMARTBLESSINGBAR("")
        assert.is_true(ns.UI.window:IsShown())
        RUNSCRIPT(ns.UI.controls.reportBug, "OnClick")
        assert.is_true(ns.reportWindow:IsShown())
        assert.is_false(ns.UI.window:IsShown())
        assert.are.equal(ns.reportWindow.reportText, ns.reportWindow.report:GetText())
        assert.are.same({}, STATE.errors)

        local again = login()
        SlashCmdList.SMARTBLESSINGBAR("bug")
        assert.is_true(again.reportWindow:IsShown())
        assert.are.equal(again.D.BUG_REPORT_URL, again.D.BUG_REPORT_URL:match("^https://github.com/.+/issues$"))
    end)

    it("is listed by /sbb help", function()
        local ns = login()
        SlashCmdList.SMARTBLESSINGBAR("help")
        local found = false
        for _, line in ipairs(CHAT) do
            if line:find("/sbb bug", 1, true) and line:find(ns.L.CMD_BUG, 1, true) then found = true end
        end
        assert.is_true(found)
    end)
end)
