-- Auras the client keeps secret out of combat: in instances and PvP it refuses an addon's read
-- with an error (BugSack, Michel, 2026-10-20: "Auras cannot be accessed when secret while
-- tainted"). The addon then acts as in combat: it reads nothing and keeps what it showed.

local addon = require("addon")

local D = addon.load("enUS").D
local M = D.BLESSINGS.MIGHT

local function login(world)
    local ns = addon.load("enUS", addon.mightFirst(world))
    STATE.known = { [D.SALVATION] = true, [D.AURAS.DEVOTION[1]] = true }
    for i = 1, 6 do STATE.known[M.normal[i]] = true end
    FIRE("PLAYER_LOGIN")
    return ns
end

local function head(b) return { b:GetAttribute("type1"), b:GetAttribute("spell1"), b:GetAttribute("unit1") } end

for _, api in ipairs({ "with C_Secrets", "without C_Secrets" }) do
    describe("secret auras out of combat, " .. api, function()
        local function secret()
            STATE.aurasSecret = true
            STATE.noSecretsApi = api == "without C_Secrets"
        end

        it("leave the buttons as they were, with no error", function()
            local ns = login({ group = "party", units = { party1 = { class = "WARRIOR" } } })
            local before = head(ns.blessingButton)
            secret()
            TICK()
            FIRE("UNIT_AURA", "player")
            RUNTIMERS()
            FIRE("GROUP_ROSTER_UPDATE")
            RUNTIMERS()
            assert.are.same({}, STATE.errors)
            assert.are.same(before, head(ns.blessingButton))
            STATE.aurasSecret = false
            STATE.units.player.auras = { { spellId = M.normal[6], expirationTime = 3600, mine = true } }
            TICK()
            assert.are.equal("party1", ns.blessingButton:GetAttribute("unit1"))
        end)

        it("let Buff & Run only move on", function()
            local ns = login()
            STATE.units.target = { class = "WARRIOR" }
            STATE.friends = { { class = "ROGUE" } }
            secret()
            RUNCLICK(ns.blessingButton, "MiddleButton", true)
            assert.are.same({}, STATE.casts)
            assert.are.equal(1, STATE.targetedNext)
            assert.are.same({}, STATE.errors)
        end)

        it("leave the overview as it was", function()
            local ns = login()
            secret()
            ns.OpenSettingsOn("TAB_PRIORITIES")
            assert.are.same({}, STATE.errors)
        end)
    end)
end
