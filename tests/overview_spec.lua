-- The overview window: members under their role, the blessings they carry, mine marked, the
-- next one faint (ruleset plan 2026-10-19-overview, phase 1).

local addon = require("addon")

local D = addon.load("enUS").D
local M, K, W = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS, D.BLESSINGS.WISDOM

-- A paladin knowing Might 1-6, Kings, Wisdom 1 and Salvation; `world` as for addon.load
local function login(world)
    world = world or {}
    local ns = addon.load("enUS", world)
    STATE.known = { [K.normal[1]] = true, [W.normal[1]] = true, [D.SALVATION] = true }
    for i = 1, 6 do STATE.known[M.normal[i]] = true end
    FIRE("PLAYER_LOGIN")
    ns.ToggleOverview()
    return ns, ns.overview
end

local function aura(id, opts)
    opts = opts or {}
    return { spellId = id, expirationTime = opts.expires or 3600, mine = opts.mine, source = opts.source }
end

-- The shown rows: { name, role of the section, column, greyed }
local function rows(o)
    local out = {}
    for _, r in ipairs(o.rows) do
        if r:IsShown() then
            out[#out + 1] = { r.name:GetText(), r.role, r.column, r.greyed == true }
        end
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
        if h:IsShown() then out[#out + 1] = { h.role, h.column } end
    end
    return out
end

describe("the overview", function()
    it("lists every member under his role, the sections in role order", function()
        local _, o = login({ group = "party", units = {
            party1 = { class = "WARRIOR", role = "TANK", name = "Grom" },
            party2 = { class = "PRIEST", name = "Anna" },
            party3 = { class = "MAGE", name = "Jaina" } } })
        assert.are.same({ { "TANK", 1 }, { "HEALER", 1 }, { "MELEE", 1 }, { "CASTER", 1 } }, headers(o))
        assert.are.same({ { "Grom", "TANK", 1, false }, { "Anna", "HEALER", 1, false },
                          { "player", "MELEE", 1, false }, { "Jaina", "CASTER", 1, false } }, rows(o))
        assert.is_true(o:IsShown())
        assert.are.same({}, STATE.errors)
    end)

    it("names a member without his second name, and marks a role set by hand", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR", name = "Grom", surname = "Hellscream" } } })
        ns.Blessings.SetHandRole(UnitGUID("party1"), "TANK")
        ns.Refresh()
        assert.are.same({ "Grom *", "TANK", 1, false }, rows(o)[1])
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

    it("uses one column up to 20 members, two from 21, a split section's header repeated", function()
        local function raid(n)
            local units = {}
            for i = 1, n do units["raid" .. i] = { class = "WARRIOR", subgroup = 1 } end
            return { group = "raid", units = units }
        end
        local _, o = login(raid(20))
        for _, r in ipairs(rows(o)) do assert.are.equal(1, r[3]) end
        _, o = login(raid(21))
        local columns = {}
        for i, r in ipairs(rows(o)) do columns[i] = r[3] end
        for i = 1, 11 do assert.are.equal(1, columns[i]) end
        for i = 12, 21 do assert.are.equal(2, columns[i]) end
        assert.are.same({ { "MELEE", 1 }, { "MELEE", 2 } }, headers(o))
    end)

    it("shows a row per class in demo mode, named by the class, only the next one faint", function()
        local ns, o = login()
        ns.Blessings.SetHandRole(UnitGUID("player"), "TANK") -- no "*" in demo mode
        SimpleBlessingBarDB.demo = true
        STATE.units.player.auras = { aura(M.normal[6], { mine = true }) }
        ns.Refresh()
        local shown = rows(o)
        assert.are.equal(#D.CLASS_ORDER, #shown)
        local names = {}
        for _, r in ipairs(shown) do names[r[1]] = true end
        for _, class in ipairs(D.CLASS_ORDER) do
            assert.is_true(names[ns.LocalName(LOCALIZED_CLASS_NAMES_MALE[class], "CLASS_" .. class)], class)
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
end)

-- The footer: per paladin in the group what he gave, and "Others" (phase 2)
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

    it("is not shown in demo mode", function()
        local ns, o = login()
        SimpleBlessingBarDB.demo = true
        ns.Refresh()
        assert.are.same({}, lines(o))
    end)
end)

-- Opening and closing (phase 3)
describe("opening the overview", function()
    local function fresh(world)
        local ns = addon.load("enUS", world)
        STATE.known = { [M.normal[1]] = true }
        FIRE("PLAYER_LOGIN")
        return ns, ns.overview
    end
    local function click(frame, button)
        RUNCLICK(frame, button, true)
        RUNCLICK(frame, button, false)
    end

    it("toggles with Shift and a right click on the blessing button; without Shift it is the role menu", function()
        local ns, o = fresh()
        click(ns.blessingButton, "RightButton")
        assert.is_false(o:IsShown() == true)
        assert.is_table(STATE.menu)
        STATE.menu = nil
        STATE.shift = true
        click(ns.blessingButton, "RightButton")
        assert.is_true(o:IsShown())
        assert.is_nil(STATE.menu)
        click(ns.blessingButton, "RightButton")
        assert.is_false(o:IsShown())
    end)

    it("toggles with /sbb overview, listed by /sbb help, and refuses in combat", function()
        local ns, o = fresh()
        SlashCmdList.SIMPLEBLESSINGBAR("overview")
        assert.is_true(o:IsShown())
        SlashCmdList.SIMPLEBLESSINGBAR("overview")
        assert.is_false(o:IsShown())
        SlashCmdList.SIMPLEBLESSINGBAR("help")
        local listed = false
        for _, l in ipairs(CHAT) do
            if l:find("/sbb overview", 1, true) and l:find(ns.L.CMD_OVERVIEW, 1, true) then listed = true end
        end
        assert.is_true(listed)
        STATE.combat = true
        SlashCmdList.SIMPLEBLESSINGBAR("overview")
        assert.is_false(o:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.NOT_IN_COMBAT, 1, true))
        assert.are.same({}, STATE.errors)
    end)

    it("toggles with a middle click on the minimap button, named in its tooltip, refused in combat", function()
        local ns, o = fresh()
        local mb = ns.minimapButton
        assert.is_true(table.concat(mb.clicks, ","):find("MiddleButtonUp", 1, true) ~= nil)
        RUNSCRIPT(mb, "OnClick", "MiddleButton")
        assert.is_true(o:IsShown())
        assert.is_false(ns.UI.window:IsShown() == true)
        RUNSCRIPT(mb, "OnClick", "MiddleButton")
        assert.is_false(o:IsShown())
        RUNSCRIPT(mb, "OnEnter")
        local found = false
        for _, l in ipairs(GameTooltip.lines) do
            if l[1] == ns.L.MIDDLECLICK and l[2] == ns.L.OVERVIEW then found = true end
        end
        assert.is_true(found)
        STATE.combat = true
        RUNSCRIPT(mb, "OnClick", "MiddleButton")
        assert.is_false(o:IsShown())
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.NOT_IN_COMBAT, 1, true))
    end)

    it("toggles with the Blessings tab's button, beside the open settings window", function()
        local ns, o = fresh()
        SlashCmdList.SIMPLEBLESSINGBAR("")
        local settings = ns.UI.window
        settings.right, settings.top = 700, 600
        RUNSCRIPT(ns.UI.controls.overviewButton, "OnClick")
        assert.is_true(o:IsShown())
        assert.is_true(settings:IsShown())
        assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 708, 600 }, { o:GetPoint() })
    end)

    it("opens centred first, then where it was left", function()
        local ns, o = fresh()
        ns.ToggleOverview()
        assert.are.equal("CENTER", (o:GetPoint()))
        o:ClearAllPoints()
        o:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 50, 500) -- dragged
        ns.ToggleOverview()
        ns.ToggleOverview()
        assert.are.same({ "TOPLEFT", UIParent, "BOTTOMLEFT", 50, 500 }, { o:GetPoint() })
    end)

    it("closes when combat starts and opens again when it ends, if combat closed it", function()
        local ns, o = fresh()
        ns.ToggleOverview()
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        assert.is_false(o:IsShown())
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_true(o:IsShown())
        ns.ToggleOverview()
        STATE.combat = true
        FIRE("PLAYER_REGEN_DISABLED")
        STATE.combat = false
        FIRE("PLAYER_REGEN_ENABLED")
        assert.is_false(o:IsShown())
        assert.are.same({}, STATE.errors)
    end)
end)

-- The role menu from a row (phase 4)
describe("a right click on an overview row", function()
    local function entry(text)
        for _, e in ipairs(STATE.menu.entries) do
            if e.text == text then return e end
        end
    end

    it("opens the role menu for that member; Tank moves him under Tank with Kings faint", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR", name = "Grom",
            auras = { aura(M.normal[6]) } } } })
        RUNSCRIPT(row(o, "party1"), "OnMouseUp", "RightButton")
        assert.are.same({ ns.L.ROLE_MENU, "Grom" }, STATE.menu.titles)
        entry(ns.L.ROLE_TANK).pick()
        local r = row(o, "party1")
        assert.are.same({ "Grom *", "TANK" }, { r.name:GetText(), r.role })
        assert.are.same({ MIGHT = { false, false }, KINGS = { false, true } }, icons(r))
        assert.are.same({}, STATE.errors)
    end)

    it("opens nothing in demo mode, nor for a left click", function()
        local ns, o = login({ group = "party", units = { party1 = { class = "WARRIOR" } } })
        RUNSCRIPT(row(o, "party1"), "OnMouseUp", "LeftButton")
        assert.is_nil(STATE.menu)
        SimpleBlessingBarDB.demo = true
        ns.Refresh()
        for _, r in ipairs(o.rows) do
            if r:IsShown() then RUNSCRIPT(r, "OnMouseUp", "RightButton") end
        end
        assert.is_nil(STATE.menu)
    end)
end)
