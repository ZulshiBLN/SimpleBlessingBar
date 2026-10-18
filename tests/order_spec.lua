-- The bar's order: aura, Righteous Fury and the class buttons as one block, the classes
-- reordered only inside it (ruleset plan 2026-10-18-settings-more, IMPLEMENTATION "Tests, by
-- phase" 2). Rows are dragged as the client does it: press, cursor moves, OnUpdate, release.

local addon = require("addon")

local ROW = 26 + 2 -- a row and its gap, as the Order page lays them out
local TOP = 1000   -- the first row's top edge on screen

-- Demo mode shows every class, so every row has a button on the bar
local function login(world)
    local ns = addon.load("enUS", world)
    FIRE("PLAYER_LOGIN")
    SimpleBlessingBarDB.demo = true
    ns.Refresh()
    return ns, SimpleBlessingBarDB, ns.D
end

local function openOrder(ns)
    SlashCmdList.SIMPLEBLESSINGBAR("")
    for i, page in ipairs(ns.UI.pages) do
        if page.titleKey == "TAB_ORDER" then RUNSCRIPT(ns.UI.tabs[i], "OnClick") return page end
    end
end

-- Drags the row in slot `from` to slot `to` (slots count rows from the top, from 1)
local function drag(ns, page, from, to)
    local rows = ns.UI.controls.orderRows
    rows[1].top = TOP
    STATE.mouseDown = true
    RUNSCRIPT(rows[from], "OnMouseDown", "LeftButton")
    STATE.cursor = { 0, TOP - (to - 1) * ROW - ROW / 2 }
    RUNSCRIPT(page, "OnUpdate", 0.01)
    STATE.mouseDown = false
    RUNSCRIPT(rows[from], "OnMouseUp", "LeftButton")
end

-- The bar's buttons from its anchor, by their layout offset
local function barOrder(ns)
    local list = {}
    local function add(b)
        if b:IsShown() then list[#list + 1] = { b = b, off = select(4, b:GetPoint()) } end
    end
    add(ns.auraButton)
    add(ns.furyButton)
    for _, b in pairs(ns.classButtons) do add(b) end
    table.sort(list, function(a, c) return a.off < c.off end)
    local out = {}
    for i, e in ipairs(list) do
        out[i] = e.b == ns.auraButton and "AURA" or e.b == ns.furyButton and "FURY" or e.b.class
    end
    return out
end

describe("the bar's order", function()
    it("starts with aura, Righteous Fury, then the classes in their default order", function()
        local ns, _, D = login()
        local expected = { "AURA", "FURY" }
        for _, class in ipairs(D.CLASS_ORDER) do expected[#expected + 1] = class end
        assert.are.same(expected, barOrder(ns))
    end)

    it("follows a saved order of the block and of the classes in it", function()
        local ns, db = login()
        db.order = { "CLASSES", "FURY", "AURA" }
        db.classOrder = { "MAGE", "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "WARLOCK", "DRUID" }
        ns.Refresh()
        local order = barOrder(ns)
        assert.are.same({ "MAGE", "WARRIOR", "PALADIN" }, { order[1], order[2], order[3] })
        assert.are.same({ "FURY", "AURA" }, { order[10], order[11] })
    end)

    it("skips classes not in the group and keeps the rest in order", function()
        local ns, db = login({ group = "party", units = { party1 = { class = "MAGE" }, party2 = { class = "WARRIOR" } } })
        db.demo = false
        db.classOrder = { "MAGE", "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "WARLOCK", "DRUID" }
        ns.Refresh()
        assert.are.same({ "AURA", "FURY", "MAGE", "WARRIOR", "PALADIN" }, barOrder(ns))
    end)
end)

describe("the Order page", function()
    it("shows the three top rows, and the classes indented under the block", function()
        local ns, _, D = login()
        openOrder(ns)
        local rows = ns.UI.controls.orderRows
        assert.are.equal(#D.DEFAULT_ORDER + #D.CLASS_ORDER, #rows)
        assert.are.equal(ns.L.TRACK_AURA, rows[1].label:GetText())
        assert.are.equal(ns.L.ORDER_CLASSES, rows[3].label:GetText())
        assert.are.equal("classWARRIOR", rows[4].label:GetText()) -- the client's name
        assert.are.equal("Interface\\Icons\\ClassIcon_WARRIOR", rows[4].icon:GetTexture())
        -- SetPoint("LEFT", x, 0): the offset is the second value
        local topX, classX = select(2, rows[3].num:GetPoint()), select(2, rows[4].num:GetPoint())
        assert.is_true(classX > topX)
        ns.ApplyLanguage("deDE")
        assert.are.equal(ns.locales.deDE.CLASS_WARRIOR, rows[4].label:GetText())
    end)

    it("moves the class block as a whole, and the bar follows on drop", function()
        local ns, db = login()
        local page = openOrder(ns)
        drag(ns, page, 3, 1)
        assert.are.same({ "CLASSES", "AURA", "FURY" }, db.order)
        local order = barOrder(ns)
        assert.are.equal("WARRIOR", order[1])
        assert.are.same({ "AURA", "FURY" }, { order[10], order[11] })
        -- the block's rows moved with it: the classes now follow the block row at the top
        assert.are.equal(ns.L.ORDER_CLASSES, ns.UI.controls.orderRows[1].label:GetText())
        assert.are.equal("classWARRIOR", ns.UI.controls.orderRows[2].label:GetText())
    end)

    it("reorders the classes inside the block", function()
        local ns, db = login()
        local page = openOrder(ns)
        drag(ns, page, 10, 4) -- Mage above Warrior
        assert.are.equal("MAGE", db.classOrder[1])
        assert.are.equal("WARRIOR", db.classOrder[2])
        local order = barOrder(ns)
        assert.are.same({ "MAGE", "WARRIOR" }, { order[3], order[4] })
    end)

    it("keeps a class inside its block when dropped outside it", function()
        local ns, db, D = login()
        local page = openOrder(ns)
        drag(ns, page, 10, 2) -- Mage onto the Righteous Fury row: first in the block, no further
        assert.are.equal("MAGE", db.classOrder[1])
        assert.are.same(D.DEFAULT_ORDER, db.order)
        drag(ns, page, 4, 1) -- dragged up again, it stays first
        assert.are.equal("MAGE", db.classOrder[1])
        assert.are.same(D.DEFAULT_ORDER, db.order)
    end)

    it("ends a drag when the mouse button was released outside the window", function()
        local ns, db = login()
        local page = openOrder(ns)
        local rows = ns.UI.controls.orderRows
        rows[1].top = TOP
        STATE.mouseDown = true
        RUNSCRIPT(rows[3], "OnMouseDown", "LeftButton")
        STATE.mouseDown = false
        RUNSCRIPT(page, "OnUpdate", 0.01)
        assert.is_nil(page:GetScript("OnUpdate"))
        assert.are.same(ns.D.DEFAULT_ORDER, db.order)
    end)

    it("restores both orders with Default, and the bar follows", function()
        local ns, db, D = login()
        local page = openOrder(ns)
        drag(ns, page, 3, 1)
        drag(ns, page, 10, 2)
        RUNSCRIPT(ns.UI.controls.orderDefault, "OnClick")
        assert.are.same(D.DEFAULT_ORDER, db.order)
        assert.are.same(D.CLASS_ORDER, db.classOrder)
        assert.are_not.equal(D.DEFAULT_ORDER, db.order) -- copies, never the defaults themselves
        assert.are_not.equal(D.CLASS_ORDER, db.classOrder)
        assert.are.equal("AURA", barOrder(ns)[1])
        assert.are.same({}, STATE.errors)
    end)

    it("keeps both orders across a login", function()
        local saved = { dbVersion = 5, order = { "FURY", "CLASSES", "AURA" },
            classOrder = { "DRUID", "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK" } }
        local ns, db = login({ db = saved })
        assert.are.same({ "FURY", "CLASSES", "AURA" }, db.order)
        assert.are.equal("DRUID", db.classOrder[1])
        assert.are.same("FURY", barOrder(ns)[1])
    end)
end)
