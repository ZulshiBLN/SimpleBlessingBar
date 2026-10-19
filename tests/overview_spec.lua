-- The overview at the foot of the Priorities tab: members by class, the blessings they carry,
-- mine marked, the next one faint, a footer per paladin (ruleset plans 2026-10-19-overview,
-- 2026-10-19-priorities).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K, W = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS, D.BLESSINGS.WISDOM

-- A paladin knowing Might 1-6, Kings, Wisdom 1 and Salvation, the settings open on the
-- Priorities tab; `world` as for addon.load
local function login(world)
    world = world or {}
    local ns = addon.load("enUS", world)
    STATE.known = { [K.normal[1]] = true, [W.normal[1]] = true, [D.SALVATION] = true }
    for i = 1, 6 do STATE.known[M.normal[i]] = true end
    FIRE("PLAYER_LOGIN")
    ns.OpenSettingsOn("TAB_PRIORITIES")
    return ns, ns.overview
end

local function aura(id, opts)
    opts = opts or {}
    return { spellId = id, expirationTime = opts.expires or 3600, mine = opts.mine, source = opts.source }
end

-- The shown rows: { name, class, greyed }
local function rows(o)
    local out = {}
    for _, r in ipairs(o.rows) do
        if r:IsShown() then out[#out + 1] = { r.name:GetText(), r.class, r.greyed == true } end
    end
    return out
end

local function row(o, unit)
    for _, r in ipairs(o.rows) do
        if r:IsShown() and r.unit == unit then return r end
    end
end

-- A row's icons by slot: family -> { mine, faint }
local function icons(r)
    local out = {}
    for _, s in ipairs(r.slots) do
        if s:IsShown() then
            assert.are.equal(s.mine == true, s.border:IsShown(), s.family) -- the gold border marks mine
            out[s.family] = { s.mine == true, s.faint == true }
        end
    end
    return out
end

local function headers(o)
    local out = {}
    for _, h in ipairs(o.headers) do
        if h:IsShown() then out[#out + 1] = h.class end
    end
    return out
end

local function className(ns, class) return ns.LocalName(LOCALIZED_CLASS_NAMES_MALE[class], "CLASS_" .. class) end

describe("the overview", function()
    it("lists every member under his class, in class order, the game's role marked", function()
        local ns, o = login({ group = "party", units = {
            party1 = { class = "WARRIOR", role = "TANK", name = "Grom" },
            party2 = { class = "PRIEST", name = "Anna" },
            party3 = { class = "MAGE", name = "Jaina" } } })
        local L = ns.L
        assert.are.same({ "WARRIOR", "PALADIN", "PRIEST", "MAGE" }, headers(o))
        assert.are.equal(className(ns, "WARRIOR"), o.headers[1]:GetText())
        assert.are.same({ { "Grom " .. L.OV_TANK, "WARRIOR", false }, { "player", "PALADIN", false },
                          { "Anna " .. L.OV_HEALER, "PRIEST", false }, { "Jaina", "MAGE", false } }, rows(o))
        assert.is_true(ns.overviewHost.page:IsShown())
        assert.are.same({}, STATE.errors)
    end)

    it("names a member without his second name", function()
        local _, o = login({ group = "party", units = { party1 = { class = "ROGUE", name = "Grom", surname = "Hellscream" } } })
        assert.are.equal("Grom", row(o, "party1").name:GetText())
    end)

    it("shows the blessings and Salvation carried, mine bordered", function()
        local _, o = login({ group = "party", units = { party1 = { class = "WARRIOR", auras = {
            aura(M.normal[6], { mine = true }), aura(K.normal[1], { source = "party2" }), aura(D.SALVATION, { mine = true }) } },
            party2 = { class = "PALADIN" } } })
        assert.are.same({ MIGHT = { true, false }, KINGS = { false, false }, SALVATION = { true, false } },
            icons(row(o, "party1")))
    end)

    it("shows the next blessing faint, also over another's lower rank", function()
        local _, o = login({ group = "party", units = { party1 = { class = "WARRIOR", auras = { aura(M.normal[1]) } } } })
        assert.are.same({ MIGHT = { false, true } }, icons(row(o, "party1")))
        local slot
        for _, s in ipairs(row(o, "party1").slots) do if s.family == "MIGHT" then slot = s end end
        assert.are.equal("+", slot.plus:GetText())
        assert.are.equal(M.normal[6], slot.spell)
    end)

    it("shows my blessing running out faint in its place", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR",
            auras = { aura(M.normal[6], { mine = true, expires = 60 }) } } } })
        ns.Refresh()
        assert.are.same({ MIGHT = { false, true } }, icons(row(o, "party1")))
    end)

    it("greys a member out of range or dead, without the faint icon", function()
        local _, o = login({ group = "party", units = { party1 = { class = "WARRIOR", range = false },
                                                        party2 = { class = "ROGUE", dead = true } } })
        assert.is_true(row(o, "party1").greyed)
        assert.is_true(row(o, "party2").greyed)
        assert.are.same({}, icons(row(o, "party1")))
        assert.is_false(row(o, "player").greyed)
    end)

    it("shows no icons for a member who is not visible", function()
        local _, o = login({ group = "party", units = { party1 = { class = "WARRIOR", visible = false,
            auras = { aura(K.normal[1], { source = "player" }) } } } })
        assert.is_true(row(o, "party1").greyed)
        assert.are.same({}, icons(row(o, "party1")))
    end)

    it("explains an icon: the spell, who gave it and the minutes left", function()
        STATE.now = 0
        local ns, o = login({ group = "party", units = {
            party1 = { class = "WARRIOR", auras = { aura(K.normal[1], { source = "party2", expires = 600 }),
                                                    aura(D.SALVATION, { expires = 0 }) } },
            party2 = { class = "PALADIN", name = "Tyr", surname = "Lightbringer" } } })
        local function tip(family)
            for _, s in ipairs(row(o, "party1").slots) do
                if s.family == family then
                    RUNSCRIPT(s, "OnEnter")
                    local lines = {}
                    for _, l in ipairs(GameTooltip.lines) do lines[#lines + 1] = l[1] end
                    return GameTooltip.spell, lines
                end
            end
        end
        local spell, lines = tip("KINGS")
        assert.are.equal(K.normal[1], spell)
        assert.are.same({ ns.L.OV_FROM:format("Tyr"), ns.L.OV_LEFT:format(10) }, lines)
        spell, lines = tip("SALVATION")
        assert.are.equal(D.SALVATION, spell)
        assert.are.same({ ns.L.OV_FROM:format(ns.L.OV_ANOTHER) }, lines)
        assert.are.same({}, STATE.errors)
    end)

    it("lists a raid of 21 in one column, taller than its scroll frame", function()
        local units = {}
        for i = 1, 21 do units["raid" .. i] = { class = "WARRIOR", subgroup = 1 } end
        local ns, o = login({ group = "raid", units = units })
        assert.are.equal(21, #rows(o))
        for _, r in ipairs(o.rows) do
            if r:IsShown() then assert.are.equal(0, select(2, r:GetPoint())) end
        end
        assert.is_true(o:GetHeight() > ns.overviewHost.scroll:GetHeight())
    end)

    it("shows a row per class in demo mode, named by the class, without marks, only the next one faint", function()
        local ns, o = login()
        SimpleBlessingBarDB.demo = true
        STATE.units.player.auras = { aura(M.normal[6], { mine = true }) }
        ns.Refresh()
        local shown = rows(o)
        assert.are.equal(#D.CLASS_ORDER, #shown)
        for i, class in ipairs(D.CLASS_ORDER) do
            assert.are.same({ className(ns, class), class, false }, shown[i])
        end
        for _, r in ipairs(o.rows) do
            if r:IsShown() then
                for _, ic in pairs(icons(r)) do assert.are.same({ false, true }, ic) end
            end
        end
    end)

    it("follows the refresh while shown", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR" } } })
        STATE.units.party1.auras = { aura(M.normal[6], { mine = true }) }
        ns.Refresh()
        assert.are.same({ MIGHT = { true, false } }, icons(row(o, "party1")))
    end)

    it("follows a language switch while open", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR" } } })
        ns.ApplyLanguage("deDE")
        assert.are.equal(ns.locales.deDE.CLASS_WARRIOR, o.headers[1]:GetText())
    end)

    it("explains the faint icon with its spell, a Greater one when only that fits", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR", level = 30 } } })
        STATE.known[M.greater[1]] = true
        STATE.learned = {}
        for i = 1, 6 do STATE.learned[M.normal[i]] = 60 end
        STATE.learned[M.greater[1]] = 40
        ns.Refresh()
        local slot
        for _, s in ipairs(row(o, "party1").slots) do if s.family == "MIGHT" then slot = s end end
        assert.is_true(slot.faint)
        RUNSCRIPT(slot, "OnEnter")
        assert.are.equal(M.greater[1], GameTooltip.spell)
    end)

    it("opens no menu on a right click, on a row or on the blessing button, Shift or not", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR" } } })
        RUNSCRIPT(row(o, "party1"), "OnMouseUp", "RightButton")
        for _, shift in ipairs({ false, true }) do
            STATE.shift = shift
            RUNCLICK(ns.blessingButton, "RightButton", true)
            RUNCLICK(ns.blessingButton, "RightButton", false)
        end
        assert.is_nil(STATE.menu)
        assert.are.same({}, STATE.errors)
    end)
end)

-- The footer: per paladin in the group what he gave, and "Others"
describe("the overview's footer", function()
    local function lines(o)
        local out = {}
        for _, f in ipairs(o.footer) do
            if f:IsShown() then out[#out + 1] = f:GetText() end
        end
        return out
    end

    local function line(ns, name, parts)
        local L = ns.L
        local pieces = {}
        for _, p in ipairs(parts) do pieces[#pieces + 1] = L.OV_COUNT:format(p[1], p[2]) end
        return L.OV_LINE:format(name, #pieces > 0 and table.concat(pieces, L.OV_SEP) or L.OV_NONE)
    end

    local function fam(ns, family) return ns.Blessings.FamilyName(family) end
    local function salv(ns) return ns.LocalName(C_Spell.GetSpellName(D.SALVATION), "SALVATION") end

    it("names each paladin, me first, with what each gave, Salvation last", function()
        local ns, o = login({ group = "party", units = {
            player = { class = "PALADIN", auras = { aura(M.normal[1], { source = "party1" }) } },
            party1 = { class = "PALADIN", name = "Tyr" },
            party2 = { class = "WARRIOR", auras = { aura(M.normal[6], { mine = true, source = "player" }),
                aura(K.normal[1], { source = "party1" }), aura(D.SALVATION, { mine = true, source = "player" }) } },
            party3 = { class = "MAGE", auras = { aura(W.normal[1], { source = "party1" }) } } } })
        assert.are.same({
            line(ns, "player", { { fam(ns, "MIGHT"), 1 }, { salv(ns), 1 } }),
            line(ns, "Tyr", { { fam(ns, "MIGHT"), 1 }, { fam(ns, "WISDOM"), 1 }, { fam(ns, "KINGS"), 1 } }),
        }, lines(o))
    end)

    it("shows a paladin who gave nothing with '-', and Others only when someone outside gave", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "PALADIN", name = "Tyr" },
            party2 = { class = "WARRIOR" } } })
        assert.are.same({ line(ns, "player", {}), line(ns, "Tyr", {}) }, lines(o))
        STATE.units.party2.auras = { aura(K.normal[1]), aura(K.normal[1], { source = "target" }) }
        STATE.units.target = { class = "PALADIN" } -- a paladin outside the group
        ns.Refresh()
        assert.are.equal(line(ns, ns.L.OV_OTHERS, { { fam(ns, "KINGS"), 1 } }), lines(o)[3])
    end)

    it("puts me first in a raid, wherever I stand in it", function()
        local ns, o = login({ group = "raid", units = { raid1 = { class = "PALADIN", name = "Tyr", subgroup = 1 } } })
        STATE.units.raid2 = STATE.units.player
        STATE.units.player.subgroup, STATE.units.player.name = 1, "Zulshe"
        ns.Refresh()
        assert.are.same({ line(ns, "Zulshe", {}), line(ns, "Tyr", {}) }, lines(o))
    end)

    it("counts Mass Salvation as Salvation, and nothing from a member who is not visible", function()
        local ns, o = login({ group = "party", units = {
            party1 = { class = "WARRIOR", auras = { aura(D.MASS_SALVATION, { source = "player" }) } },
            party2 = { class = "MAGE", visible = false, auras = { aura(W.normal[1], { source = "player" }) } } } })
        assert.are.equal(line(ns, "player", { { salv(ns), 1 } }), o.footer[1]:GetText())
    end)

    it("widens the overview to its longest line", function()
        local _, o = login({ group = "party", units = { party1 = { class = "PALADIN", name = "Tyr" },
            party2 = { class = "WARRIOR", auras = { aura(M.normal[6], { source = "party1" }),
                aura(D.SALVATION, { source = "party1" }) } },
            party3 = { class = "MAGE", auras = { aura(W.normal[1], { source = "party1" }),
                aura(K.normal[1], { source = "party1" }) } } } })
        local widest = 0
        for _, f in ipairs(o.footer) do
            if f:IsShown() then widest = math.max(widest, f:GetStringWidth()) end
        end
        assert.is_true(o:GetWidth() >= widest, o:GetWidth() .. " < " .. widest)
    end)

    it("is not shown in demo mode", function()
        local ns, o = login()
        SimpleBlessingBarDB.demo = true
        ns.Refresh()
        assert.are.same({}, lines(o))
    end)
end)

-- Opening: the minimap button's middle click, nothing else (ruleset plan 2026-10-19-priorities)
describe("opening the overview", function()
    local function fresh()
        local ns = addon.load("enUS")
        STATE.known = { [M.normal[1]] = true }
        FIRE("PLAYER_LOGIN")
        return ns, ns.UI.window, ns.overviewHost.page
    end

    it("opens the settings on the Priorities tab with a middle click on the minimap button", function()
        local ns, window, page = fresh()
        local mb = ns.minimapButton
        assert.is_truthy(table.concat(mb.clicks, ","):find("MiddleButtonUp", 1, true))
        RUNSCRIPT(mb, "OnClick", "MiddleButton")
        assert.is_true(window:IsShown())
        assert.is_true(page:IsShown())
        RUNSCRIPT(mb, "OnClick", "MiddleButton")
        assert.is_false(window:IsShown())
        assert.are.same({}, STATE.errors)
    end)

    it("switches to the Priorities tab when the window shows another", function()
        local ns, window, page = fresh()
        SlashCmdList.SIMPLEBLESSINGBAR("")
        RUNSCRIPT(ns.UI.tabs[1], "OnClick")
        assert.is_false(page:IsShown())
        RUNSCRIPT(ns.minimapButton, "OnClick", "MiddleButton")
        assert.is_true(window:IsShown())
        assert.is_true(page:IsShown())
    end)

    it("names the middle click in the minimap button's tooltip", function()
        local ns = fresh()
        RUNSCRIPT(ns.minimapButton, "OnEnter")
        local found = false
        for _, l in ipairs(GameTooltip.lines) do
            if l[1] == ns.L.MIDDLECLICK and l[2] == ns.L.TAB_PRIORITIES then found = true end
        end
        assert.is_true(found)
    end)

    it("says why nothing opens in combat", function()
        local ns, window = fresh()
        STATE.combat = true
        RUNSCRIPT(ns.minimapButton, "OnClick", "MiddleButton")
        assert.is_false(window:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.NOT_IN_COMBAT, 1, true))
    end)

    it("has no chat command and no window of its own any more", function()
        local ns = fresh()
        SlashCmdList.SIMPLEBLESSINGBAR("overview")
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.CMD_UNKNOWN:format("|cffffd100/sbb help|r"), 1, true))
        assert.is_nil(ns.ToggleOverview)
        assert.is_nil(_G.SimpleBlessingBarOverview)
    end)
end)
