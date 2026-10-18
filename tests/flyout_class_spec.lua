-- Flyout.lua with the class buttons: the icons and their targets, choosing in and out of
-- combat, one flyout at a time (ruleset plan 2026-10-18-flyouts, IMPLEMENTATION "Tests,
-- by phase" 3). Clicks go through RUNCLICK, which runs the secure snippets.

local addon = require("addon")

local function click(frame, mouseButton)
    RUNCLICK(frame, mouseButton, true)
    RUNCLICK(frame, mouseButton, false)
end

-- The flyout's icon for a blessing family, or nil
local function iconFor(fly, family)
    for _, icon in ipairs(fly.icons) do
        if icon:IsShown() and icon.family == family then return icon end
    end
end

-- A party: the paladin, a warrior lacking everything, a second warrior out of range.
-- Might rank 1 and Kings are known.
local function party(extra)
    local ns = addon.load("enUS", { group = "party", units = {
        party1 = { class = "WARRIOR" },
        party2 = { class = "WARRIOR", range = false },
    } })
    local B = ns.D.BLESSINGS
    STATE.known = { [B.MIGHT.normal[1]] = true, [B.KINGS.normal[1]] = true }
    if extra then extra(ns.D) end
    FIRE("PLAYER_LOGIN")
    return ns, ns.D, ns.flyouts.WARRIOR, ns.classButtons.WARRIOR
end

describe("a class flyout", function()
    it("lists the known blessings, as Greater Blessings with a Symbol of Kings", function()
        local _, D, fly = party()
        assert.are.equal(D.BLESSINGS.MIGHT.normal[1], iconFor(fly, "MIGHT"):GetAttribute("sbbspell"))
        assert.is_truthy(iconFor(fly, "KINGS"))
        assert.is_nil(iconFor(fly, "WISDOM"))

        local _, D2, fly2 = party(function(data)
            STATE.known[data.BLESSINGS.MIGHT.greater[1]] = true
            STATE.bags[data.SYMBOL_OF_KINGS] = 2
        end)
        assert.are.equal(D2.BLESSINGS.MIGHT.greater[1], iconFor(fly2, "MIGHT"):GetAttribute("sbbspell"))
    end)

    it("selects a blessing without casting; the class button then casts it on the member lacking it", function()
        local ns, D, fly, button = party()
        assert.is_nil(button:GetAttribute("type1")) -- nothing assigned yet
        click(button, "RightButton")
        assert.is_true(fly:IsShown())
        click(iconFor(fly, "KINGS"), "LeftButton")
        local kings = D.BLESSINGS.KINGS.normal[1]
        assert.are.equal(0, #STATE.casts)
        assert.is_false(fly:IsShown())
        assert.are.equal("KINGS", SimpleBlessingBarDB.assign.WARRIOR)
        click(button, "LeftButton")
        assert.are.same({ { spell = kings, unit = "party1" } }, STATE.casts)
        assert.is_false(button.classIcon:IsDesaturated())
        assert.is_table(ns.flyouts.AURA)
    end)

    it("selects in combat, the button casts it, and the count follows after combat", function()
        local _, D, fly, button = party()
        SimpleBlessingBarDB.assign.WARRIOR = "MIGHT"
        FIRE("GROUP_ROSTER_UPDATE")
        RUNTIMERS()
        assert.are.equal("2", button.count:GetText())

        STATE.combat = true
        click(button, "RightButton")
        click(iconFor(fly, "KINGS"), "LeftButton")
        assert.are.equal(0, #STATE.casts)
        click(button, "LeftButton")
        assert.are.same({ { spell = D.BLESSINGS.KINGS.normal[1], unit = "party1" } }, STATE.casts)
        assert.are.equal("KINGS", SimpleBlessingBarDB.assign.WARRIOR)
        assert.are.same({}, STATE.errors)
        assert.are.equal("2", button.count:GetText())

        STATE.units.party1.auras = { { spellId = D.BLESSINGS.KINGS.normal[1], expirationTime = 3600, mine = true } }
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.are.equal("1", button.count:GetText())
    end)

    it("greys an icon with nobody in range, which selects and saves nothing", function()
        local _, _, fly, button = party()
        STATE.units.party1.range = false
        TICK()
        local icon = iconFor(fly, "MIGHT")
        assert.is_true(icon.icon:IsDesaturated())
        click(button, "RightButton")
        click(icon, "LeftButton")
        assert.are.equal(0, #STATE.casts)
        assert.is_nil(SimpleBlessingBarDB.assign.WARRIOR)
        assert.is_nil(button:GetAttribute("type1"))
        assert.is_true(fly:IsShown())
    end)

    it("closes the other flyouts when it opens", function()
        local ns, _, fly, button = party()
        click(ns.auraButton, "RightButton")
        assert.is_true(ns.flyouts.AURA:IsShown())
        click(button, "RightButton")
        assert.is_true(fly:IsShown())
        assert.is_false(ns.flyouts.AURA:IsShown())
        click(ns.classButtons.PALADIN, "RightButton")
        assert.is_false(fly:IsShown())
        assert.is_true(ns.flyouts.PALADIN:IsShown())
    end)
end)

describe("a Salvation icon", function()
    it("targets only the paladin's own party, Mass Salvation the whole class", function()
        local me = { class = "PALADIN", subgroup = 1 }
        local ns = addon.load("enUS", { group = "raid", units = {
            player = me, raid1 = me,
            raid2 = { class = "ROGUE", subgroup = 2 },
        } })
        local S = ns.D.BLESSINGS.SALVATION
        STATE.known = { [S.normal[1]] = true }
        FIRE("PLAYER_LOGIN")
        local icon = iconFor(ns.flyouts.ROGUE, "SALVATION")
        assert.is_nil(icon:GetAttribute("sbbunit"))
        assert.is_nil(icon:GetAttribute("sbbspell"))

        STATE.known[S.greater[1]] = true
        STATE.bags[ns.D.SYMBOL_OF_KINGS] = 1
        TICK()
        assert.are.equal("raid2", icon:GetAttribute("sbbunit"))
        assert.are.equal(S.greater[1], icon:GetAttribute("sbbspell"))
    end)
end)
