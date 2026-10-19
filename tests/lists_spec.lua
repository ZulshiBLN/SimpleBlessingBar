-- The Blessings tab: a priority list per role, dragged and switched off by the player (ruleset
-- plan 2026-10-19-blessing-steering, phase 2). Icons are dragged as the client does it:
-- press, cursor moves, OnUpdate, release.

local addon = require("addon")

local D = addon.load("enUS").D
local M, K, W = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS, D.BLESSINGS.WISDOM

local ICON = 24 + 6 -- an icon and its gap, as the tab lays them out
local LEFT = 300    -- the first icon's left edge on screen

-- A paladin alone knowing Might, Kings and Wisdom; `db` is the saved file
local function login(db)
    local ns = addon.load("enUS", { db = db })
    STATE.known = { [M.normal[1]] = true, [K.normal[1]] = true, [W.normal[1]] = true }
    FIRE("PLAYER_LOGIN")
    ns.Refresh()
    return ns, SimpleBlessingBarDB
end

local function openTab(ns)
    SlashCmdList.SIMPLEBLESSINGBAR("")
    for i, page in ipairs(ns.UI.pages) do
        if page.titleKey == "TAB_BLESSINGS" then RUNSCRIPT(ns.UI.tabs[i], "OnClick") return page end
    end
end

-- The row of a role
local function row(ns, role)
    for _, r in ipairs(ns.UI.controls.listRows) do
        if r.role == role then return r end
    end
end

-- The families a row shows, and which are greyed
local function shown(r)
    local families, grey = {}, {}
    for i, icon in ipairs(r.icons) do
        families[i] = icon.family
        grey[i] = icon.tex.desaturated == true
    end
    return families, grey
end

-- Drags the icon in slot `from` of a row to slot `to`
local function drag(page, r, from, to)
    r.icons[1].left = LEFT
    STATE.mouseDown = true
    RUNSCRIPT(r.icons[from], "OnMouseDown", "LeftButton")
    STATE.cursor = { LEFT + (to - 1) * ICON + ICON / 2, 0 }
    RUNSCRIPT(page, "OnUpdate", 0.01)
    STATE.mouseDown = false
    RUNSCRIPT(r.icons[from], "OnMouseUp", "LeftButton")
end

local function rightClick(icon) RUNSCRIPT(icon, "OnMouseUp", "RightButton") end

-- A deep copy, so a later InitDB cannot change what a test compares against
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

describe("the Blessings tab", function()
    it("shows a row per role, named, with its default list", function()
        local ns = login()
        openTab(ns)
        local rows = ns.UI.controls.listRows
        assert.are.equal(#D.ROLES, #rows)
        for i, role in ipairs(D.ROLES) do
            assert.are.equal(role, rows[i].role)
            assert.are.equal(ns.L["ROLE_" .. role], rows[i].label:GetText())
            assert.are.same(D.ROLE_LISTS[role], (shown(rows[i])))
        end
    end)

    it("moves a blessing within its row, and the button follows on drop", function()
        local ns, db = login()
        local page = openTab(ns)
        local melee = row(ns, "MELEE")
        drag(page, melee, 4, 1)
        assert.are.same({ "WISDOM", "MIGHT", "KINGS", "LIGHT" }, db.roleLists.MELEE.order)
        assert.are.same({ "WISDOM", "MIGHT", "KINGS", "LIGHT" }, (shown(melee)))
        assert.are.equal(W.normal[1], ns.blessingButton:GetAttribute("spell1"))
        assert.is_nil(page:GetScript("OnUpdate"))
    end)

    it("keeps a saved list after a reload", function()
        local ns = login({ dbVersion = 7, roleLists = { MELEE = { order = { "WISDOM", "MIGHT", "KINGS", "LIGHT" }, off = {} } } })
        assert.are.equal(W.normal[1], ns.blessingButton:GetAttribute("spell1"))
    end)

    it("switches a blessing off with a right click, greyed at the end, and on again last", function()
        local ns, db = login()
        openTab(ns)
        local melee = row(ns, "MELEE")
        rightClick(melee.icons[1])
        assert.are.same({ "KINGS", "LIGHT", "WISDOM" }, db.roleLists.MELEE.order)
        assert.are.same({ MIGHT = true }, db.roleLists.MELEE.off)
        local families, grey = shown(melee)
        assert.are.same({ "KINGS", "LIGHT", "WISDOM", "MIGHT" }, families)
        assert.are.same({ false, false, false, true }, grey)
        assert.are.equal(K.normal[1], ns.blessingButton:GetAttribute("spell1"))
        rightClick(melee.icons[4])
        assert.are.same({ "KINGS", "LIGHT", "WISDOM", "MIGHT" }, db.roleLists.MELEE.order)
        assert.are.same({}, db.roleLists.MELEE.off)
        assert.are.equal(K.normal[1], ns.blessingButton:GetAttribute("spell1"))
    end)

    it("shows the game's tooltip of the best known rank, rank 1 when none is known", function()
        local ns = login()
        STATE.known[M.normal[2]] = true
        openTab(ns)
        local melee = row(ns, "MELEE")
        RUNSCRIPT(melee.icons[1], "OnEnter")
        assert.are.equal(M.normal[2], GameTooltip.spell)
        RUNSCRIPT(melee.icons[3], "OnEnter")
        assert.are.equal(D.BLESSINGS.LIGHT.normal[1], GameTooltip.spell)
        assert.are.same({}, STATE.errors)
    end)

    it("keeps one blessing on", function()
        local ns, db = login({ dbVersion = 7, roleLists = { MELEE = { order = { "KINGS" }, off = { MIGHT = true, LIGHT = true, WISDOM = true } } } })
        openTab(ns)
        rightClick(row(ns, "MELEE").icons[1])
        assert.are.same({ "KINGS" }, db.roleLists.MELEE.order)
    end)

    it("drags no blessing that is off", function()
        local ns = login()
        local page = openTab(ns)
        local melee = row(ns, "MELEE")
        rightClick(melee.icons[1])
        STATE.mouseDown = true
        RUNSCRIPT(melee.icons[4], "OnMouseDown", "LeftButton")
        assert.is_nil(page:GetScript("OnUpdate"))
    end)

    it("restores every row with Default, as a copy, and the button follows", function()
        local ns, db = login()
        local page = openTab(ns)
        drag(page, row(ns, "MELEE"), 4, 1)
        rightClick(row(ns, "TANK").icons[1])
        RUNSCRIPT(ns.UI.controls.listsDefault, "OnClick")
        for _, role in ipairs(D.ROLES) do
            assert.are.same(D.ROLE_LISTS[role], db.roleLists[role].order)
            assert.are_not.equal(D.ROLE_LISTS[role], db.roleLists[role].order)
            assert.are.same({}, db.roleLists[role].off)
        end
        assert.are.equal(M.normal[1], ns.blessingButton:GetAttribute("spell1"))
        assert.are.same({}, STATE.errors)
    end)
end)

-- Version 7 (ruleset plan 2026-10-19-blessing-steering): the lists are checked at login
describe("settings version 7", function()
    local function lists(saved)
        local ns = addon.load("enUS", { db = { dbVersion = 7, roleLists = saved } })
        ns.InitDB()
        return SimpleBlessingBarDB.roleLists, ns.D
    end
    local function default(role) return { order = D.ROLE_LISTS[role], off = {} } end

    it("gives a version-6 file the default lists, and changes nothing the second time", function()
        local ns = addon.load("enUS", { db = { dbVersion = 6 } })
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.equal(7, db.dbVersion)
        for _, role in ipairs(D.ROLES) do assert.are.same(default(role), db.roleLists[role]) end
        local once = copy(db)
        ns.InitDB()
        assert.are.same(once, SimpleBlessingBarDB)
    end)

    it("replaces lists that are not a table, and drops unknown roles", function()
        for _, bad in ipairs({ "x", 5 }) do
            local saved = lists(bad)
            for _, role in ipairs(D.ROLES) do assert.are.same(default(role), saved[role]) end
        end
        assert.is_nil(lists({ BOGUS = { order = { "MIGHT" }, off = {} } }).BOGUS)
    end)

    it("gives a missing role, or any part not a table, its default", function()
        local saved = lists({ TANK = "x", HEALER = { order = "x", off = {} }, MELEE = { order = { "KINGS" }, off = 5 } })
        assert.are.same(default("TANK"), saved.TANK)
        assert.are.same(default("HEALER"), saved.HEALER)
        assert.are.same(default("MELEE"), saved.MELEE)
        assert.are.same(default("CASTER"), saved.CASTER)
    end)

    it("cleans a list: unknown and doubled families out, missing ones appended, off kept", function()
        local saved = lists({ MELEE = { order = { "KINGS", "SANCTUARY", "KINGS", 7 },
                                        off = { MIGHT = true, KINGS = true, BOGUS = true, LIGHT = 1 } } })
        assert.are.same({ order = { "KINGS", "WISDOM", "LIGHT" }, off = { MIGHT = true } }, saved.MELEE)
    end)

    it("gives a list with nothing on its default", function()
        local saved = lists({ MELEE = { order = {}, off = { MIGHT = true, KINGS = true, LIGHT = true, WISDOM = true } } })
        assert.are.same(default("MELEE"), saved.MELEE)
    end)
end)
