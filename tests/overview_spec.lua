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
