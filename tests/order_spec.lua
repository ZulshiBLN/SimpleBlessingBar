-- The bar's order: aura, Righteous Fury, blessing and Salvation, by drag and drop (ruleset
-- plans 2026-10-18-settings-more and 2026-10-19-blessing-core). Rows are dragged as the
-- client does it: press, cursor moves, OnUpdate, release.

local addon = require("addon")

local ROW = 26 + 2 -- a row and its gap, as the Order page lays them out
local TOP = 1000   -- the first row's top edge on screen

local function login(world)
    local ns = addon.load("enUS", world)
    FIRE("PLAYER_LOGIN")
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
    local names = { [ns.auraButton] = "AURA", [ns.furyButton] = "FURY",
                    [ns.blessingButton] = "BLESSING", [ns.salvationButton] = "SALVATION" }
    local list = {}
    for b, name in pairs(names) do
        if b:IsShown() then list[#list + 1] = { name = name, off = select(4, b:GetPoint()) } end
    end
    table.sort(list, function(a, c) return a.off < c.off end)
    local out = {}
    for i, e in ipairs(list) do out[i] = e.name end
    return out
end

describe("the bar's order", function()
    it("starts with aura, Righteous Fury, blessing, Salvation", function()
        local ns, _, D = login()
        assert.are.same(D.DEFAULT_ORDER, barOrder(ns))
    end)

    it("follows a saved order, also after a login", function()
        local ns = login({ db = { dbVersion = 6, order = { "SALVATION", "FURY", "AURA", "BLESSING" } } })
        assert.are.same({ "SALVATION", "FURY", "AURA", "BLESSING" }, barOrder(ns))
    end)
end)

describe("the Order page", function()
    it("shows a row per button, named and in order", function()
        local ns = login()
        openOrder(ns)
        local rows = ns.UI.controls.orderRows
        assert.are.equal(4, #rows)
        assert.are.equal(ns.L.TRACK_AURA, rows[1].label:GetText())
        assert.are.equal(ns.L.BTN_BLESSINGS, rows[3].label:GetText())
        assert.are.equal("spell" .. ns.D.SALVATION, rows[4].label:GetText()) -- the client's name
    end)

    it("moves a row, and the bar follows on drop", function()
        local ns, db = login()
        local page = openOrder(ns)
        drag(ns, page, 3, 1)
        assert.are.same({ "BLESSING", "AURA", "FURY", "SALVATION" }, db.order)
        assert.are.same({ "BLESSING", "AURA", "FURY", "SALVATION" }, barOrder(ns))
        assert.are.equal(ns.L.BTN_BLESSINGS, ns.UI.controls.orderRows[1].label:GetText())
    end)

    it("ends a drag when the mouse button was released outside the window", function()
        local ns, db, D = login()
        local page = openOrder(ns)
        local rows = ns.UI.controls.orderRows
        rows[1].top = TOP
        STATE.mouseDown = true
        RUNSCRIPT(rows[3], "OnMouseDown", "LeftButton")
        STATE.mouseDown = false
        RUNSCRIPT(page, "OnUpdate", 0.01)
        assert.is_nil(page:GetScript("OnUpdate"))
        assert.are.same(D.DEFAULT_ORDER, db.order)
    end)

    it("restores the default order, as a copy, and the bar follows", function()
        local ns, db, D = login()
        local page = openOrder(ns)
        drag(ns, page, 4, 1)
        RUNSCRIPT(ns.UI.controls.orderDefault, "OnClick")
        assert.are.same(D.DEFAULT_ORDER, db.order)
        assert.are_not.equal(D.DEFAULT_ORDER, db.order)
        assert.are.same(D.DEFAULT_ORDER, barOrder(ns))
        assert.are.same({}, STATE.errors)
    end)
end)
