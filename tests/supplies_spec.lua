-- Supplies: the Symbol of Kings count on class buttons and the auto-buy (ruleset plan
-- 2026-10-18-settings-more, IMPLEMENTATION "Tests, by phase" 1).

local addon = require("addon")

-- A paladin alone who knows Might and, unless told otherwise, Greater Might; Might is
-- assigned to paladins. `bags` = Symbols carried.
local function login(opts)
    opts = opts or {}
    local ns = addon.load("enUS")
    local D = ns.D
    local M = D.BLESSINGS.MIGHT
    STATE.known = { [M.normal[1]] = true, [M.greater[1]] = not opts.noGreater or nil,
                    [D.BLESSINGS.WISDOM.normal[1]] = true }
    STATE.bags = { [D.SYMBOL_OF_KINGS] = opts.bags or 0 }
    STATE.money = opts.money or 1000000
    FIRE("PLAYER_LOGIN")
    local db = SimpleBlessingBarDB
    db.assign.PALADIN = "MIGHT"
    for k, v in pairs(opts.db or {}) do db[k] = v end
    ns.Refresh()
    return ns, db, D, ns.classButtons.PALADIN
end

local function color(fs) return { unpack(fs.textColor, 1, 4) } end
local function rgba(c) return { c.r, c.g, c.b, c.a } end

describe("the Symbol count", function()
    it("shows the Symbols centred on a class button whose blessing has a known Greater form", function()
        local _, _, _, b = login({ bags = 7 })
        assert.are.equal("7", b.symbols:GetText())
        assert.are.equal("CENTER", (b.symbols:GetPoint()))
        assert.are.same({ 1, 1, 1, 1 }, color(b.symbols))
    end)

    it("shows nothing without a known Greater form", function()
        local _, _, _, b = login({ bags = 7, noGreater = true })
        assert.are.equal("", b.symbols:GetText())
        local ns, db, _, b2 = login({ bags = 7 })
        db.assign.PALADIN = "WISDOM" -- Greater Wisdom is not learned
        ns.Refresh()
        assert.are.equal("", b2.symbols:GetText())
    end)

    it("turns the warning color at or below the threshold and the empty color at 0", function()
        local ns, db, D, b = login({ bags = 5 })
        assert.are.equal(D.NUMBER_DEFAULTS.symbolWarn.default, db.symbolWarn)
        assert.are.same(rgba(db.symbolWarnColor), color(b.symbols))
        STATE.bags[D.SYMBOL_OF_KINGS] = 6
        ns.Refresh()
        assert.are.same({ 1, 1, 1, 1 }, color(b.symbols))
        STATE.bags[D.SYMBOL_OF_KINGS] = 0
        ns.Refresh()
        assert.are.equal("0", b.symbols:GetText())
        assert.are.same(rgba(db.symbolZeroColor), color(b.symbols))
    end)

    it("never warns with a threshold of 0", function()
        local _, _, _, b = login({ bags = 1, db = { symbolWarn = 0 } })
        assert.are.same({ 1, 1, 1, 1 }, color(b.symbols))
    end)

    it("shows the sample count in demo mode on an assigned class, none on an unassigned one", function()
        local ns, db, D = login({ noGreater = true })
        db.demo = true
        ns.Refresh()
        assert.are.equal(tostring(D.DEMO_SYMBOLS), ns.classButtons.PALADIN.symbols:GetText())
        assert.are.equal("", ns.classButtons.MAGE.symbols:GetText())
    end)
end)

describe("the auto-buy", function()
    -- A reagent vendor as on Forever: Symbols at 3000 copper per stack of 20, max stack 100
    local function vendor(D, maxStack)
        return { { id = 159, price = 25, stack = 1, maxStack = 20 },
                 { id = D.SYMBOL_OF_KINGS, price = 3000, stack = 20, maxStack = maxStack or 100 } }
    end
    local function visit()
        FIRE("MERCHANT_SHOW")
    end

    it("buys the difference to the target, and says what and for how much", function()
        local ns, db, D = login({ bags = 5, db = { autoBuy = true } })
        STATE.merchant = vendor(D)
        visit()
        assert.are.same({ { 2, 15 } }, STATE.bought)
        assert.are.equal(db.symbolAmount, STATE.bags[D.SYMBOL_OF_KINGS])
        -- the client's own name: the addon speaks the client's language
        assert.is_truthy(CHAT[#CHAT - 1]:find(ns.L.BUYING:format(15, "item" .. D.SYMBOL_OF_KINGS), 1, true))
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.COST:format("2250c"), 1, true))
    end)

    it("buys only what the gold above the reserve pays, and names the reserve", function()
        local ns, _, D = login({ bags = 5, money = 10000 + 10 * 150, db = { autoBuy = true } })
        STATE.merchant = vendor(D)
        visit()
        assert.are.same({ { 2, 10 } }, STATE.bought)
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.RESERVE_REACHED:format("10000c"), 1, true))
    end)

    it("buys nothing when off, without a known Greater Blessing, or at the target", function()
        local _, _, D = login({ bags = 5 })
        STATE.merchant = vendor(D)
        visit()
        assert.is_nil(STATE.bought)
        login({ bags = 5, noGreater = true, db = { autoBuy = true } })
        STATE.merchant = vendor(D)
        visit()
        assert.is_nil(STATE.bought)
        login({ bags = 25, db = { autoBuy = true } })
        STATE.merchant = vendor(D)
        visit()
        assert.is_nil(STATE.bought)
    end)

    it("buys once when the vendor fills its list late", function()
        local _, _, D = login({ bags = 5, db = { autoBuy = true } })
        visit() -- the list is still empty
        assert.is_nil(STATE.bought)
        STATE.merchant = vendor(D)
        FIRE("MERCHANT_UPDATE")
        assert.are.same({ { 2, 15 } }, STATE.bought)
        -- later updates (a sale, a bag change) buy nothing, even with room and past the lock
        STATE.bags[D.SYMBOL_OF_KINGS] = 5
        STATE.now = D.BUY_LOCK + 1
        FIRE("MERCHANT_UPDATE")
        assert.are.same({ { 2, 15 } }, STATE.bought)
    end)

    it("starts no purchase within the lock after the last one", function()
        local _, _, D = login({ bags = 5, db = { autoBuy = true } })
        STATE.merchant = vendor(D)
        visit()
        STATE.bags[D.SYMBOL_OF_KINGS] = 5 -- the bags have not caught up yet
        STATE.now = D.BUY_LOCK - 1
        FIRE("MERCHANT_CLOSED")
        visit()
        assert.are.equal(1, #STATE.bought)
        STATE.now = D.BUY_LOCK + 1
        visit()
        assert.are.equal(2, #STATE.bought)
    end)

    it("splits the purchase at the vendor's maximum stack", function()
        local _, _, D = login({ bags = 5, db = { autoBuy = true } })
        STATE.merchant = vendor(D, 10)
        visit()
        assert.are.same({ { 2, 10 }, { 2, 5 } }, STATE.bought)
    end)

    it("never buys an item without a gold price", function()
        local _, _, D = login({ bags = 5, db = { autoBuy = true } })
        STATE.merchant = vendor(D)
        STATE.merchant[2].price = 0
        visit()
        assert.is_nil(STATE.bought)
    end)

    it("only says what it would buy in demo mode, from the real bags", function()
        local ns, db, D = login({ bags = 5, noGreater = true, db = { autoBuy = true } })
        db.demo = true
        STATE.merchant = vendor(D)
        visit()
        assert.is_nil(STATE.bought)
        assert.is_truthy(CHAT[#CHAT - 1]:find(ns.L.DEMO_BUY:format(15, "item" .. D.SYMBOL_OF_KINGS), 1, true))
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.DEMO_COST:format("2250c"), 1, true))
        assert.are.same({}, STATE.errors)
    end)
end)

describe("the Supplies page", function()
    local function open(opts)
        local ns, db, D, b = login(opts)
        SlashCmdList.SIMPLEBLESSINGBAR("")
        return ns, ns.UI.controls, db, D, b
    end

    it("sets the threshold, and the Symbol count follows at once", function()
        local _, c, db, _, b = open({ bags = 6 })
        assert.are.same({ 1, 1, 1, 1 }, color(b.symbols))
        c.symbolWarn:SetValue(8)
        assert.are.equal(8, db.symbolWarn)
        assert.are.same(rgba(db.symbolWarnColor), color(b.symbols))
        c.symbolWarnBox:SetText("3")
        RUNSCRIPT(c.symbolWarnBox, "OnEnterPressed")
        assert.are.equal(3, db.symbolWarn)
        assert.are.same({ 1, 1, 1, 1 }, color(b.symbols))
    end)

    it("colors the count from its swatches", function()
        local _, c, db, D, b = open({ bags = 0 })
        RUNSCRIPT(c.symbolZeroColor, "OnClick")
        STATE.pickedColor = { 0, 0, 1, 1 }
        ColorPickerFrame.info.swatchFunc()
        assert.are.same({ r = 0, g = 0, b = 1, a = 1 }, db.symbolZeroColor)
        assert.are.same({ 0, 0, 1, 1 }, color(b.symbols))
        STATE.bags[D.SYMBOL_OF_KINGS] = 2
        RUNSCRIPT(c.symbolWarnColor, "OnClick")
        STATE.pickedColor = { 0, 1, 0, 1 }
        ColorPickerFrame.info.swatchFunc()
        assert.are.same({ 0, 1, 0, 1 }, color(b.symbols))
    end)

    it("dims the amounts while auto-buy is off, and sets them", function()
        local _, c, db = open()
        for _, row in ipairs(c.amountRows) do assert.are.equal(0.4, row:GetAlpha()) end
        c.autoBuy:SetChecked(true)
        RUNSCRIPT(c.autoBuy, "OnClick")
        assert.is_true(db.autoBuy)
        for _, row in ipairs(c.amountRows) do assert.are.equal(1, row:GetAlpha()) end
        c.symbolAmount:SetValue(40)
        c.goldReserve:SetValue(12)
        assert.are.same({ 40, 12 }, { db.symbolAmount, db.goldReserve })
    end)
end)
