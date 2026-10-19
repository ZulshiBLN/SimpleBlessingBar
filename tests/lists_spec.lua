-- The Priorities tab: the renewal, a priority list per class in two columns, dragged and
-- switched off, Enable all, the aura list, dragged, and the overview (ruleset plans
-- 2026-10-19-blessing-steering, 2026-10-19-priorities). Icons are dragged as the client does
-- it: press, cursor moves, OnUpdate, release.

local addon = require("addon")

local D = addon.load("enUS").D
local M, K, W = D.BLESSINGS.MIGHT, D.BLESSINGS.KINGS, D.BLESSINGS.WISDOM

local ICON = 24 + 6 -- an icon and its gap, as the tab lays them out
local LEFT = 300    -- the first icon's left edge on screen

-- A paladin alone knowing Might, Kings, Wisdom and Devotion and Retribution Aura; `db` is the
-- saved file
local function login(db)
    local ns = addon.load("enUS", { db = db })
    STATE.known = { [M.normal[1]] = true, [K.normal[1]] = true, [W.normal[1]] = true,
                    [D.AURAS.DEVOTION[1]] = true, [D.AURAS.RETRIBUTION[1]] = true }
    FIRE("PLAYER_LOGIN")
    ns.Refresh()
    return ns, SimpleBlessingBarDB
end

local function openTab(ns)
    SlashCmdList.SIMPLEBLESSINGBAR("")
    for i, page in ipairs(ns.UI.pages) do
        if page.titleKey == "TAB_PRIORITIES" then RUNSCRIPT(ns.UI.tabs[i], "OnClick") return page end
    end
end

-- The row of a class
local function row(ns, class)
    for _, r in ipairs(ns.UI.controls.listRows) do
        if r.class == class then return r end
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

-- A class's default: the list of its default role
local function classDefault(class) return D.ROLE_LISTS[D.CLASS_ROLES[class][1]] end

-- A deep copy, so a later InitDB cannot change what a test compares against
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

describe("the Priorities tab", function()
    -- The x and y offsets a frame was placed at, for both SetPoint forms: (point, x, y) and
    -- (point, relative, relativePoint, x, y)
    local function offsets(frame)
        local a = { frame:GetPoint() }
        if type(a[2]) == "number" then return a[2], a[3] end
        return a[4], a[5]
    end
    local function top(frame) return select(2, offsets(frame)) end

    it("stands between Supplies and Order, laid out top to bottom", function()
        local ns = login()
        local page = openTab(ns)
        local keys = {}
        for i, pg in ipairs(ns.UI.pages) do keys[i] = pg.titleKey end
        local at = {}
        for i, k in ipairs(keys) do at[k] = i end
        assert.are.equal(at.TAB_SUPPLIES + 1, at.TAB_PRIORITIES)
        assert.are.equal(at.TAB_PRIORITIES + 1, at.TAB_ORDER)
        local c = ns.UI.controls
        -- renewal, Auras title, aura row, an empty line, Blessings title, class rows, buttons,
        -- overview (ruleset plan 2026-10-19-tab-layout)
        local order = { top(c.auraTitle), top(c.auraRow), top(c.blessingsTitle), top(c.listRows[1]),
                        top(c.listsDefault), top(c.overviewScroll) }
        for i = 2, #order do assert.is_true(order[i] < order[i - 1], "element " .. i) end
        assert.is_true(top(c.auraRow) - top(c.blessingsTitle) >= 24 + 6 + 24, "an empty line between")
        assert.is_true(top(c.listRows[1]) < top(c.blessingsTitle))
        assert.is_true(top(c.listRows[5]) > top(c.listsDefault))
        assert.are.equal(page, ns.overviewHost.page)
    end)

    it("titles the aura and blessing lists in gold, centred", function()
        local ns = login()
        local page = openTab(ns)
        local c = ns.UI.controls
        for _, case in ipairs({ { c.auraTitle, ns.L.AURA_LIST }, { c.blessingsTitle, ns.L.BTN_BLESSINGS } }) do
            local title, text = case[1], case[2]
            assert.are.equal(text, title:GetText())
            local point, rel, relPoint, x = title:GetPoint()
            assert.are.same({ "TOP", page, "TOP", 0 }, { point, rel, relPoint, x })
        end
    end)

    it("centres the aura row, without a label, 204 px wide", function()
        local ns = login()
        local page = openTab(ns)
        local auraRow = ns.UI.controls.auraRow
        assert.is_nil(auraRow.label)
        assert.are.equal(7 * 24 + 6 * 6, auraRow:GetWidth())
        local point, rel, relPoint, x = auraRow:GetPoint()
        assert.are.same({ "TOP", page, "TOP", 0 }, { point, rel, relPoint, x })
    end)

    it("centres Default and Enable all as a pair, also after a language switch", function()
        local ns = login()
        local page = openTab(ns)
        local c = ns.UI.controls
        local function check()
            local point, rel, relPoint, x = c.listsDefault:GetPoint()
            assert.are.same({ "TOPLEFT", page, "TOP" }, { point, rel, relPoint })
            assert.are.equal(-(c.listsDefault:GetWidth() + 8 + c.enableAll:GetWidth()) / 2, x)
        end
        check()
        ns.ApplyLanguage("deDE")
        check()
    end)

    it("says how to use the lists in two short lines", function()
        local ns = login()
        assert.are.equal("The order in which you give blessings.\nDrag to reorder, right-click to toggle on/off",
            ns.L.LISTS_HINT)
    end)

    it("puts five classes in the left column and four in the right, a line between them", function()
        local ns = login()
        openTab(ns)
        local rows = ns.UI.controls.listRows
        for i = 1, #D.CLASS_ORDER do
            assert.are.equal(i <= 5 and 1 or 2, rows[i].column, D.CLASS_ORDER[i])
        end
        assert.are.equal(top(rows[1]), top(rows[6]))
        assert.is_true(select(2, rows[6]:GetPoint()) > select(2, rows[1]:GetPoint()))
        assert.is_truthy(ns.UI.controls.listsDivider)
    end)

    it("shows a row per class, named by the class, with its default list, and the aura row", function()
        local ns = login()
        openTab(ns)
        for i, class in ipairs(D.CLASS_ORDER) do
            local r = ns.UI.controls.listRows[i]
            assert.are.equal(class, r.class)
            assert.are.equal(ns.LocalName(LOCALIZED_CLASS_NAMES_MALE[class], "CLASS_" .. class), r.label:GetText())
            assert.are.same(classDefault(class), (shown(r)))
        end
        local auraRow = ns.UI.controls.auraRow
        assert.are.same(D.AURA_ORDER, (shown(auraRow)))
    end)

    it("moves a blessing within a class row, and the button follows on drop", function()
        local ns, db = login()
        local page = openTab(ns)
        local pal = row(ns, "PALADIN")
        drag(page, pal, 4, 1)
        assert.are.same({ "WISDOM", "MIGHT", "KINGS", "LIGHT" }, db.classLists.PALADIN.order)
        assert.are.same({ "WISDOM", "MIGHT", "KINGS", "LIGHT" }, (shown(pal)))
        assert.are.equal(W.normal[1], ns.blessingButton:GetAttribute("spell1"))
        assert.is_nil(page:GetScript("OnUpdate"))
    end)

    it("keeps a saved list after a reload", function()
        local ns = login({ dbVersion = 8, classLists = { PALADIN = { order = { "WISDOM", "MIGHT", "KINGS", "LIGHT" }, off = {} } } })
        assert.are.equal(W.normal[1], ns.blessingButton:GetAttribute("spell1"))
    end)

    it("switches a blessing off with a right click, greyed at the end, and on again last", function()
        local ns, db = login()
        openTab(ns)
        local pal = row(ns, "PALADIN")
        rightClick(pal.icons[1])
        assert.are.same({ "KINGS", "LIGHT", "WISDOM" }, db.classLists.PALADIN.order)
        assert.are.same({ MIGHT = true }, db.classLists.PALADIN.off)
        local families, grey = shown(pal)
        assert.are.same({ "KINGS", "LIGHT", "WISDOM", "MIGHT" }, families)
        assert.are.same({ false, false, false, true }, grey)
        assert.are.equal(K.normal[1], ns.blessingButton:GetAttribute("spell1"))
        rightClick(pal.icons[4])
        assert.are.same({ "KINGS", "LIGHT", "WISDOM", "MIGHT" }, db.classLists.PALADIN.order)
        assert.are.same({}, db.classLists.PALADIN.off)
    end)

    it("keeps one blessing on", function()
        local ns, db = login({ dbVersion = 8, classLists = { PALADIN = { order = { "KINGS" }, off = { MIGHT = true, LIGHT = true, WISDOM = true } } } })
        openTab(ns)
        rightClick(row(ns, "PALADIN").icons[1])
        assert.are.same({ "KINGS" }, db.classLists.PALADIN.order)
    end)

    it("drags no blessing that is off", function()
        local ns = login()
        local page = openTab(ns)
        local pal = row(ns, "PALADIN")
        rightClick(pal.icons[1])
        STATE.mouseDown = true
        RUNSCRIPT(pal.icons[4], "OnMouseDown", "LeftButton")
        assert.is_nil(page:GetScript("OnUpdate"))
    end)

    it("switches every blessing on again with Enable all, the order kept", function()
        local ns, db = login()
        local page = openTab(ns)
        local pal = row(ns, "PALADIN")
        drag(page, pal, 4, 1) -- Wisdom, Might, Kings, Light
        rightClick(pal.icons[2]) -- Might off
        rightClick(row(ns, "WARRIOR").icons[1]) -- the warrior's Might off
        RUNSCRIPT(ns.UI.controls.enableAll, "OnClick")
        assert.are.same({ "WISDOM", "KINGS", "LIGHT", "MIGHT" }, db.classLists.PALADIN.order)
        assert.are.same({}, db.classLists.PALADIN.off)
        assert.are.same({ "KINGS", "LIGHT", "WISDOM", "MIGHT" }, db.classLists.WARRIOR.order)
        assert.are.same({}, db.classLists.WARRIOR.off)
        assert.are.equal(W.normal[1], ns.blessingButton:GetAttribute("spell1"))
    end)

    it("reorders the aura list by drag, the aura button follows, and switches nothing off", function()
        local ns, db = login()
        local page = openTab(ns)
        local auraRow = ns.UI.controls.auraRow
        assert.are.equal(D.AURAS.DEVOTION[1], ns.auraButton:GetAttribute("spell1"))
        drag(page, auraRow, 2, 1)
        assert.are.same("RETRIBUTION", db.auraList[1])
        assert.are.equal(D.AURAS.RETRIBUTION[1], ns.auraButton:GetAttribute("spell1"))
        rightClick(auraRow.icons[1])
        assert.are.equal("RETRIBUTION", db.auraList[1])
        assert.are.equal(#D.AURA_ORDER, #db.auraList)
    end)

    it("restores every list, blessings and auras, with Default, as copies", function()
        local ns, db = login()
        local page = openTab(ns)
        drag(page, row(ns, "PALADIN"), 4, 1)
        rightClick(row(ns, "WARRIOR").icons[1])
        drag(page, ns.UI.controls.auraRow, 2, 1)
        RUNSCRIPT(ns.UI.controls.listsDefault, "OnClick")
        for _, class in ipairs(D.CLASS_ORDER) do
            assert.are.same(classDefault(class), db.classLists[class].order)
            assert.are_not.equal(classDefault(class), db.classLists[class].order)
            assert.are.same({}, db.classLists[class].off)
        end
        assert.are.same(D.AURA_ORDER, db.auraList)
        assert.are_not.equal(D.AURA_ORDER, db.auraList)
        assert.are.equal(M.normal[1], ns.blessingButton:GetAttribute("spell1"))
        assert.are.same({}, STATE.errors)
    end)

    it("shows the game's tooltip of the best known rank, rank 1 when none is known", function()
        local ns = login()
        STATE.known[M.normal[2]] = true
        openTab(ns)
        local pal = row(ns, "PALADIN")
        RUNSCRIPT(pal.icons[1], "OnEnter")
        assert.are.equal(M.normal[2], GameTooltip.spell)
        RUNSCRIPT(pal.icons[3], "OnEnter")
        assert.are.equal(D.BLESSINGS.LIGHT.normal[1], GameTooltip.spell)
        assert.are.same({}, STATE.errors)
    end)
end)

-- Version 8 (ruleset plan 2026-10-19-priorities): lists by class, the aura list, checked at
-- login
describe("settings version 8", function()
    local function lists(saved)
        local ns = addon.load("enUS", { db = { dbVersion = 8, classLists = saved } })
        ns.InitDB()
        return SimpleBlessingBarDB.classLists
    end
    local function default(class) return { order = classDefault(class), off = {} } end

    it("migrates a version-7 file: each class from its default role's list, the aura first", function()
        local ns = addon.load("enUS", { db = { dbVersion = 7, aura = "CONCENTRATION",
            flyoutDir = "FIRST", flyoutAutoClose = false, flyoutAutoCloseTime = 2,
            roleLists = { MELEE = { order = { "KINGS", "MIGHT", "LIGHT", "WISDOM" }, off = {} },
                          CASTER = { order = { "KINGS" }, off = { WISDOM = true, LIGHT = true, MIGHT = true } },
                          TANK = { order = { "LIGHT" }, off = {} } } } })
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.equal(8, db.dbVersion)
        assert.are.same({ "KINGS", "MIGHT", "LIGHT", "WISDOM" }, db.classLists.WARRIOR.order) -- melee
        assert.are.same({ order = { "KINGS" }, off = { WISDOM = true, LIGHT = true, MIGHT = true } }, db.classLists.MAGE)
        assert.are.same(default("PRIEST"), db.classLists.PRIEST) -- healer, not saved: default
        assert.are.same("CONCENTRATION", db.auraList[1])
        assert.are.equal(#D.AURA_ORDER, #db.auraList)
        for _, key in ipairs({ "aura", "roleLists", "flyoutDir", "flyoutAutoClose", "flyoutAutoCloseTime" }) do
            assert.is_nil(db[key], key)
        end
        local once = copy(db)
        ns.InitDB()
        assert.are.same(once, SimpleBlessingBarDB)
    end)

    it("gives an older file without lists the defaults, and an unknown aura the default order", function()
        local ns = addon.load("enUS", { db = { dbVersion = 5, aura = "SANCTUARY" } })
        ns.InitDB()
        local db = SimpleBlessingBarDB
        for _, class in ipairs(D.CLASS_ORDER) do assert.are.same(default(class), db.classLists[class]) end
        assert.are.same(D.AURA_ORDER, db.auraList)
    end)

    it("replaces lists that are not a table, and drops unknown classes", function()
        for _, bad in ipairs({ "x", 5 }) do
            local saved = lists(bad)
            for _, class in ipairs(D.CLASS_ORDER) do assert.are.same(default(class), saved[class]) end
        end
        assert.is_nil(lists({ DEATHKNIGHT = { order = { "MIGHT" }, off = {} } }).DEATHKNIGHT)
    end)

    it("gives a missing class, or any part not a table, its default", function()
        local saved = lists({ WARRIOR = "x", PRIEST = { order = "x", off = {} }, MAGE = { order = { "KINGS" }, off = 5 } })
        assert.are.same(default("WARRIOR"), saved.WARRIOR)
        assert.are.same(default("PRIEST"), saved.PRIEST)
        assert.are.same(default("MAGE"), saved.MAGE)
        assert.are.same(default("DRUID"), saved.DRUID)
    end)

    it("cleans a list: unknown and doubled families out, missing ones appended, off kept", function()
        local saved = lists({ WARRIOR = { order = { "KINGS", "SANCTUARY", "KINGS", 7 },
                                          off = { MIGHT = true, KINGS = true, BOGUS = true, LIGHT = 1 } } })
        assert.are.same({ order = { "KINGS", "WISDOM", "LIGHT" }, off = { MIGHT = true } }, saved.WARRIOR)
    end)

    it("gives a list with nothing on, or only unknown families, its default", function()
        local saved = lists({ WARRIOR = { order = {}, off = {} }, ROGUE = { order = { "BOGUS" }, off = { MIGHT = true } } })
        assert.are.same(default("WARRIOR"), saved.WARRIOR)
        assert.are.same(default("ROGUE"), saved.ROGUE)
    end)

    it("repairs a damaged aura list", function()
        local ns = addon.load("enUS", { db = { dbVersion = 8, auraList = { "FIRE", "BOGUS", "FIRE" } } })
        ns.InitDB()
        local list = SimpleBlessingBarDB.auraList
        assert.are.equal("FIRE", list[1])
        assert.are.equal(#D.AURA_ORDER, #list)
    end)
end)
