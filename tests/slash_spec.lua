-- Main.lua: /sbb and its commands (ruleset plan 2026-10-18-class-blessing-bar,
-- IMPLEMENTATION "Tests, by phase" 5).

local addon = require("addon")

local function login()
    local ns = addon.load("enUS")
    FIRE("PLAYER_LOGIN")
    return ns
end

local function sbb(msg)
    SlashCmdList.SMARTBLESSINGBAR(msg)
end

-- Whether any chat line printed since `from` contains the text
local function printed(text, from)
    for i = from or 1, #CHAT do
        if CHAT[i]:find(text, 1, true) then return true end
    end
    return false
end

describe("/sbb", function()
    it("is the command, and help lists every command, the window's too", function()
        local ns = login()
        assert.are.equal("/sbb", SLASH_SMARTBLESSINGBAR1)
        for _, msg in ipairs({ "help", "  HELP " }) do
            local from = #CHAT + 1
            sbb(msg)
            assert.is_true(printed(ns.L.HELP_HEADER, from), msg)
            for _, cmd in ipairs({ "help", "lock", "reset" }) do
                assert.is_true(printed("/sbb " .. cmd, from), msg .. ": " .. cmd)
            end
            assert.is_true(printed(ns.L.CMD_OPEN, from), msg)
        end
    end)

    it("alone opens the settings window, and lists nothing", function()
        local ns = login()
        local from = #CHAT + 1
        sbb("")
        assert.is_true(ns.UI.window:IsShown())
        assert.is_false(printed(ns.L.HELP_HEADER, from))
    end)

    it("lock toggles the lock and says which", function()
        local ns = login()
        assert.is_false(SmartBlessingBarDB.locked)
        sbb("lock")
        assert.is_true(SmartBlessingBarDB.locked)
        assert.is_true(printed(ns.L.LOCKED, #CHAT))
        sbb("lock")
        assert.is_false(SmartBlessingBarDB.locked)
        assert.is_true(printed(ns.L.UNLOCKED, #CHAT))
    end)

    it("reset moves the bar back to its start, and is refused in combat", function()
        local ns = addon.load("enUS", { db = { dbVersion = 2, point = "LEFT", rel = "BOTTOMLEFT", x = 300, y = 400 } })
        FIRE("PLAYER_LOGIN")
        STATE.combat = true
        sbb("reset")
        assert.are.equal(300, SmartBlessingBarDB.x)
        assert.is_true(printed(ns.L.NOT_IN_COMBAT, #CHAT))
        assert.are.same({}, STATE.errors)

        STATE.combat = false
        sbb("reset")
        assert.is_nil(SmartBlessingBarDB.point)
        assert.are.equal("CENTER", (ns.bar:GetPoint()))
        assert.is_true(printed(ns.L.POS_RESET, #CHAT))
    end)

    it("answers an unknown command with a pointer to help", function()
        local ns = login()
        sbb("dance")
        assert.is_true(printed(ns.L.CMD_UNKNOWN:format(""):sub(1, 10), #CHAT))
    end)
end)
