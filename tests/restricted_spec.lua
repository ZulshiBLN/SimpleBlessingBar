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

-- Third release review: the gate stopped the layout and every setting too. A login or
-- /reload while auras are secret must still build the bar, arm Buff & Run and open the
-- settings; only the planners wait.
describe("a login while auras are secret", function()
    local function secretLogin()
        local ns = addon.load("enUS", addon.mightFirst())
        STATE.known = { [M.normal[1]] = true, [D.AURAS.DEVOTION[1]] = true }
        STATE.aurasSecret = true
        FIRE("PLAYER_LOGIN")
        return ns
    end

    it("builds the bar with its icons and arms Buff & Run", function()
        local ns = secretLogin()
        for _, b in ipairs({ ns.auraButton, ns.furyButton, ns.blessingButton, ns.salvationButton }) do
            assert.is_not_nil(b:GetPoint())
            assert.is_not_nil(b.icon:GetTexture())
        end
        assert.are.equal("macro", ns.blessingButton:GetAttribute("type3"))
        assert.are.same({}, STATE.errors)
    end)

    it("opens the settings", function()
        local ns = secretLogin()
        SlashCmdList.SMARTBLESSINGBAR("")
        assert.is_true(ns.UI.window:IsShown())
        assert.are.same({}, STATE.errors)
    end)

    it("casts nothing once demo mode is switched on", function()
        local ns = addon.load("enUS", addon.mightFirst())
        STATE.known = { [M.normal[1]] = true }
        FIRE("PLAYER_LOGIN")
        assert.are.equal("spell", ns.blessingButton:GetAttribute("type1"))
        STATE.aurasSecret = true
        SmartBlessingBarDB.demo = true
        ns.Refresh()
        assert.is_nil(ns.blessingButton:GetAttribute("type1"))
        assert.is_nil(ns.auraButton:GetAttribute("type1"))
    end)
end)
