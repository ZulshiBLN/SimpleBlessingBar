-- Demo mode's raid in the overview: 40 made-up members, four Paladins with their auras and
-- blessings, tanks and healers, a few dimmed or lacking Salvation (ruleset plan
-- 2026-10-19-demo-raid).

local addon = require("addon")

local D = addon.load("enUS").D

-- A paladin knowing a Kings rank, the settings open on the Priorities tab, demo mode on;
-- `seed` for math.random
local function demo(seed)
    math.randomseed(seed or 1)
    local ns = addon.load("enUS")
    STATE.known = { [D.BLESSINGS.KINGS.normal[1]] = true }
    FIRE("PLAYER_LOGIN")
    SimpleBlessingBarDB.demo = true
    ns.OpenSettingsOn("TAB_PRIORITIES")
    ns.Refresh()
    return ns, ns.overview
end

local function shown(o)
    local out = {}
    for _, r in ipairs(o.rows) do
        if r:IsShown() then out[#out + 1] = r end
    end
    return out
end

local function count(list, pred)
    local n = 0
    for _, v in ipairs(list) do if pred(v) then n = n + 1 end end
    return n
end

local function slot(r, family)
    for _, s in ipairs(r.slots) do if s.family == family then return s end end
end

-- The tooltip's lines over a slot
local function tip(s)
    RUNSCRIPT(s, "OnEnter")
    local lines = {}
    for _, l in ipairs(GameTooltip.lines) do lines[#lines + 1] = l[1] end
    return lines
end

-- What depends on chance is checked over this many seeds
local SEEDS = 20

local WISDOM_CLASSES ={ PALADIN = true, PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true }

describe("the demo raid", function()
    it("has 40 members of all nine classes, exactly four of them Paladins", function()
        local _, o = demo()
        local rows = shown(o)
        assert.are.equal(40, #rows)
        local classes = {}
        for _, r in ipairs(rows) do classes[r.class] = (classes[r.class] or 0) + 1 end
        for _, class in ipairs(D.CLASS_ORDER) do assert.is_truthy(classes[class], class) end
        assert.are.equal(4, classes.PALADIN)
        assert.are.same({}, STATE.errors)
    end)

    it("has 4 tanks and 10 healers as in a raid, the damage dealers no Paladin, whatever the seed", function()
        -- More seeds: chance alone leaves a class out of 22 drawn in about one raid of 20
        for seed = 1, 5 * SEEDS do
            local ns = demo(seed)
            local members = ns.Blessings.Overview()
            local function classesOf(match)
                local out = {}
                for _, d in ipairs(members) do
                    if match[d.role] then out[d.class] = (out[d.class] or 0) + 1 end
                end
                return out
            end
            assert.are.same({ WARRIOR = 3, DRUID = 1 }, classesOf({ TANK = true }))
            assert.are.same({ PALADIN = 4, PRIEST = 3, SHAMAN = 2, DRUID = 1 }, classesOf({ HEALER = true }))
            -- a damage dealer has his class's first damage role
            local dps = classesOf({ MELEE = true, RANGED = true, CASTER = true })
            local n = 0
            for _, c in pairs(dps) do n = n + c end
            assert.are.equal(26, n)
            assert.is_nil(dps.PALADIN)
            for _, class in ipairs({ "HUNTER", "ROGUE", "MAGE", "WARLOCK" }) do assert.is_truthy(dps[class], class) end
        end
    end)

    it("shuffles the members", function()
        local tankFirst = 0
        for seed = 1, SEEDS do
            if demo(seed).Blessings.Overview()[1].role == "TANK" then tankFirst = tankFirst + 1 end
        end
        assert.is_true(tankFirst < SEEDS)
    end)

    it("marks tanks and healers after their names", function()
        local ns, o = demo()
        local L = ns.L
        local rows = shown(o)
        assert.are.equal(4, count(rows, function(r) return r.name:GetText():sub(-#L.OV_TANK - 1) == " " .. L.OV_TANK end))
        assert.are.equal(10, count(rows, function(r) return r.name:GetText():sub(-#L.OV_HEALER - 1) == " " .. L.OV_HEALER end))
    end)

    it("has the player as a healing Paladin under his own name", function()
        local ns, o = demo()
        local me = count(shown(o), function(r)
            return r.name:GetText() == "player " .. ns.L.OV_HEALER and r.class == "PALADIN"
        end)
        assert.are.equal(1, me)
    end)

    it("names the others 2 to 12 letters, a capital first, one of 2", function()
        local ns = demo()
        local two = 0
        for _, d in ipairs(ns.Blessings.Overview()) do
            if d.name ~= "player" then
                assert.is_truthy(d.name:match("^%u%l+$"), d.name)
                assert.is_true(#d.name >= 2 and #d.name <= 12, d.name)
                if #d.name == 2 then two = two + 1 end
            end
        end
        assert.is_true(two >= 1)
    end)

    it("lets every Paladin run a different aura: mine the chosen one, the others the first three besides it", function()
        local ns, o = demo()
        local mine = ns.Blessings.ChooseAura()
        local others = {}
        for _, family in ipairs(D.AURA_ORDER) do
            if family ~= mine and #others < 3 then others[#others + 1] = family end
        end
        local seen = {}
        for _, r in ipairs(shown(o)) do
            if r.class == "PALADIN" then
                assert.is_true(r.aura:IsShown())
                local family = ns.Blessings.AURA_FAMILY[r.aura.spell]
                assert.is_truthy(family)
                local name = r.name:GetText():gsub(" %(H%)$", "")
                if name == "player" then assert.are.equal(mine, family) end
                assert.are.same({ ns.L.OV_FROM:format(name) }, tip(r.aura))
                seen[#seen + 1] = family
            else
                assert.is_false(r.aura:IsShown())
            end
        end
        table.sort(seen)
        local want = { mine, others[1], others[2], others[3] }
        table.sort(want)
        assert.are.same(want, seen)
    end)

    -- Members and tanks per class, from the shown rows
    local function classSizes(o)
        local size, tanks = {}, {}
        for _, r in ipairs(shown(o)) do
            size[r.class] = (size[r.class] or 0) + 1
            if r.role == "TANK" then tanks[r.class] = (tanks[r.class] or 0) + 1 end
        end
        return size, tanks
    end

    -- The rank the planner would give a class of `n`: Greater from three on, else the best
    -- normal one
    local function rankFor(family, n)
        local f = D.BLESSINGS[family]
        return n >= D.RAID_GREATER_MIN and f.greater[#f.greater] or f.normal[#f.normal]
    end

    it("gives each member the first of his class's list from me, the rest from one other Paladin each", function()
        for seed = 1, SEEDS do
            local ns, o = demo(seed)
            local L, lists = ns.L, SimpleBlessingBarDB.classLists
            local size = classSizes(o)
            local givers = {}
            for _, r in ipairs(shown(o)) do
                local first = lists[r.class].order[1]
                local s = slot(r, first)
                assert.is_true(s:IsShown() and s.mine == true, r.class .. " " .. first)
                assert.are.equal(L.OV_FROM:format("player"), tip(s)[1])
                assert.are.equal(rankFor(first, size[r.class]), s.spell)
                local might = WISDOM_CLASSES[r.class] and "WISDOM" or "MIGHT"
                for _, family in ipairs({ "KINGS", "LIGHT", might }) do
                    if family ~= first then
                        s = slot(r, family)
                        assert.is_true(s:IsShown(), r.class .. " " .. family)
                        assert.is_false(s.faint == true or s.mine == true)
                        assert.are.equal(rankFor(family, size[r.class]), s.spell)
                        local key = family == "WISDOM" and "MIGHT" or family
                        givers[key] = givers[key] or tip(s)[1]
                        assert.are.equal(givers[key], tip(s)[1])
                    end
                end
            end
            assert.are_not.equal(givers.KINGS, givers.LIGHT)
            assert.are_not.equal(givers.KINGS, givers.MIGHT)
            assert.are_not.equal(givers.LIGHT, givers.MIGHT)
            for _, g in pairs(givers) do assert.are_not.equal(L.OV_FROM:format("player"), g) end
        end
    end)

    it("follows a change of a class's list at once", function()
        local ns, o = demo()
        local warrior = SimpleBlessingBarDB.classLists.WARRIOR
        table.insert(warrior.order, 1, "WISDOM")
        ns.Refresh()
        for _, r in ipairs(shown(o)) do
            if r.class == "WARRIOR" then
                local s = slot(r, "WISDOM")
                assert.is_true(s:IsShown() and s.mine == true)
                assert.is_true(slot(r, "MIGHT"):IsShown())
            end
        end
    end)

    it("gives Salvation, mine, to every non-tank but three, who show it faint as my next; Mass Salvation as the planner", function()
        for seed = 1, SEEDS do
            local ns, o = demo(seed)
            local size, tanks = classSizes(o)
            local lacking = 0
            for _, r in ipairs(shown(o)) do
                local s = slot(r, "SALVATION")
                if r.role == "TANK" then
                    assert.is_false(s:IsShown())
                elseif s.faint then
                    lacking = lacking + 1
                    assert.are.equal(D.SALVATION, s.spell)
                    assert.are.equal("+", s.plus:GetText())
                    assert.is_false(r.greyed == true)
                    assert.is_nil(r.name:GetText():find("^player"))
                else
                    assert.is_true(s:IsShown())
                    assert.is_true(s.mine)
                    assert.are.same(ns.L.OV_FROM:format("player"), tip(s)[1])
                    local t = tanks[r.class] or 0
                    local mass = size[r.class] - t >= D.RAID_GREATER_MIN + t
                    assert.are.equal(mass and D.MASS_SALVATION or D.SALVATION, s.spell, r.class)
                end
            end
            assert.are.equal(3, lacking)
            -- a member shown lacking it does not carry it either
            for _, d in ipairs(ns.Blessings.Overview()) do
                if d.next then assert.is_nil(d.carried.SALVATION) end
            end
        end
    end)

    it("dims three members, never the player", function()
        for seed = 1, SEEDS do
            local _, o = demo(seed)
            local rows = shown(o)
            assert.are.equal(3, count(rows, function(r) return r.greyed == true end))
            for _, r in ipairs(rows) do
                if r.greyed then
                    assert.are.equal(0.4, r.name:GetAlpha())
                    assert.is_false(r.name:GetText():find("^player") ~= nil)
                end
            end
        end
    end)

    it("shows 1 to 15 minutes left, also long after it was made", function()
        STATE.now = 0
        local ns, o = demo()
        STATE.now = 3600
        ns.Refresh()
        for _, r in ipairs(shown(o)) do
            local lines = tip(slot(r, "KINGS"))
            local minutes = tonumber(lines[2]:match("%d+"))
            assert.is_true(minutes >= 1 and minutes <= 15, lines[2])
        end
    end)

    it("keeps the raid on a refresh; another load with another seed makes another", function()
        local ns = demo(1)
        local function names()
            local out = {}
            for _, d in ipairs(ns.Blessings.Overview()) do out[#out + 1] = d.name end
            table.sort(out)
            return table.concat(out, ",")
        end
        local first = names()
        ns.Refresh()
        assert.are.equal(first, names())
        ns = demo(2)
        assert.are_not.equal(first, names())
    end)

    it("lets mine glow - the list's first and Salvation - no other icon", function()
        local _, o = demo()
        local glowing = 0
        for _, r in ipairs(shown(o)) do
            local first = SimpleBlessingBarDB.classLists[r.class].order[1]
            for _, s in ipairs(r.slots) do
                if s:IsShown() and s.glow:IsShown() then
                    glowing = glowing + 1
                    assert.is_true(s.family == "SALVATION" or s.family == first)
                    assert.is_false(s.faint == true)
                end
            end
        end
        assert.are.equal(40 + 40 - 4 - 3, glowing)
    end)

    -- The two names at the field's edge: a 12-letter one, cut where the field is narrower, and
    -- the longest part of it that fits (the mock measures 7 px a letter)
    local function edges(o)
        local cut, fit
        for _, r in ipairs(shown(o)) do
            if r.edge == "cut" then cut = r.name:GetText() end
            if r.edge == "fit" then fit = r.name:GetText() end
        end
        return cut, fit
    end

    it("fits two names to the name field, following the window's width", function()
        local ns, o = demo()
        for _, st in ipairs(ns.UI.stretchers) do st(400) end
        local field = ns.overview.rows[1].name:GetWidth()
        assert.is_true(field < 84, field)
        local cut, fit = edges(o)
        assert.are.equal(12, #cut)
        -- wide letters only: twelve narrow ones fit the field whole in game
        assert.is_truthy(cut:lower():match("^[mwodagnu]+$"), cut)
        assert.is_true(#cut * 7 > field)
        assert.are.equal(math.floor(field / 7), #fit)
        assert.are.equal(cut:sub(1, #fit), fit)
        for _, st in ipairs(ns.UI.stretchers) do st(600) end
        field = ns.overview.rows[1].name:GetWidth()
        assert.is_true(field >= 84, field)
        local cut2, fit2 = edges(o)
        assert.are.equal(cut, cut2)
        assert.are.equal(cut, fit2)
    end)

    it("passes no made-up unit to the client", function()
        local ns, o = demo()
        for _, d in ipairs(ns.Blessings.Overview()) do assert.is_nil(d.unit) end
        for _, r in ipairs(shown(o)) do assert.is_nil(r.unit) end
        assert.are.same({}, STATE.errors)
    end)

    it("shows the real group again when demo mode goes off", function()
        local ns, o = demo()
        SimpleBlessingBarDB.demo = false
        ns.Refresh()
        local rows = shown(o)
        assert.are.equal(1, #rows)
        assert.are.equal("player", rows[1].unit)
    end)
end)
