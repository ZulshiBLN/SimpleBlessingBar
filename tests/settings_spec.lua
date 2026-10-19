-- Settings version 2: defaults, the migration from version 1, and validation of damaged
-- values (ruleset plan 2026-10-18-class-blessing-bar, IMPLEMENTATION "Settings").

local addon = require("addon")

-- A deep copy, so a later InitDB cannot change what a test compares against
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

describe("settings", function()
    it("start with the default aura, unlocked and no position", function()
        local ns = addon.load("enUS")
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.equal(ns.D.DEFAULT_AURA, db.aura)
        assert.is_false(db.locked)
        assert.is_nil(db.point)
        assert.are.equal(ns.D.DB_VERSION, db.dbVersion)
    end)

    it("migrate a version 1 file, and a second run changes nothing", function()
        local ns = addon.load("enUS", { db = { dbVersion = 1 } })
        ns.InitDB()
        local once = copy(SimpleBlessingBarDB)
        assert.are.equal(ns.D.DB_VERSION, once.dbVersion)
        ns.InitDB()
        assert.are.same(once, SimpleBlessingBarDB)
    end)

    it("replace a damaged aura, lock and position", function()
        local ns = addon.load("enUS", { db = {
            dbVersion = 2, assign = "x", aura = "FOO", locked = "yes",
            point = "CENTER", rel = "CENTER", x = 0 / 0, y = 10,
        } })
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.is_nil(db.assign) -- version 6 drops the class assignments
        assert.are.equal(ns.D.DEFAULT_AURA, db.aura)
        assert.is_false(db.locked)
        assert.is_nil(db.point)
        assert.is_nil(db.x)
    end)

    it("keep a valid position", function()
        local ns = addon.load("enUS", { db = { dbVersion = 2, point = "TOP", rel = "TOP", x = 12, y = -40 } })
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.same({ "TOP", "TOP", 12, -40 }, { db.point, db.rel, db.x, db.y })
    end)
end)

-- Version 3 (ruleset plan 2026-10-18-settings-window, IMPLEMENTATION "Settings, version 3").
-- Every default and range is read from Data.lua.
describe("settings version 3", function()
    it("start with every default, from a version 2 file, and a second run changes nothing", function()
        local ns = addon.load("enUS", { db = { dbVersion = 2, assign = { WARRIOR = "MIGHT" } } })
        local D = ns.D
        ns.InitDB()
        local db = SimpleBlessingBarDB
        for key, default in pairs(D.BOOL_DEFAULTS) do assert.are.equal(default, db[key], key) end
        for key, n in pairs(D.NUMBER_DEFAULTS) do assert.are.equal(n.default, db[key], key) end
        for key, color in pairs(D.COLOR_DEFAULTS) do assert.are.same(color, db[key], key) end
        local once = copy(db)
        ns.InitDB()
        assert.are.same(once, SimpleBlessingBarDB)
    end)

    it("copy the color defaults instead of sharing them", function()
        local ns = addon.load("enUS")
        ns.InitDB()
        local before = copy(ns.D.BG_COLOR)
        SimpleBlessingBarDB.bg.r = 0.5
        assert.are.same(before, ns.D.BG_COLOR)
    end)

    it("clamp numbers, repair colors and booleans, and replace what is unusable", function()
        local ns = addon.load("enUS", { db = { dbVersion = 3,
            scale = 9, auraAntsSpeed = 0, furyAntsSpeed = 2.6, flyoutAutoCloseTime = 0 / 0,
            showBorder = "yes", vertical = true,
            bg = "x", countColor = { r = 5, g = -1, b = "z", a = 0.5 },
        } })
        local D = ns.D
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.equal(D.SCALE_MAX, db.scale)
        assert.are.equal(D.ANTS_SPEED_MIN, db.auraAntsSpeed)
        assert.are.equal(3, db.furyAntsSpeed) -- whole steps: 2.6 rounds to 3
        assert.are.equal(D.NUMBER_DEFAULTS.flyoutAutoCloseTime.default, db.flyoutAutoCloseTime)
        assert.are.equal(D.BOOL_DEFAULTS.showBorder, db.showBorder)
        assert.is_true(db.vertical)
        assert.are.same(D.COLOR_DEFAULTS.bg, db.bg)
        assert.are.same({ r = 1, g = 0, b = D.COLOR_DEFAULTS.countColor.b, a = 0.5 }, db.countColor)
    end)

    it("never keep demo mode across a login", function()
        local ns = addon.load("enUS", { db = { dbVersion = 3, demo = true } })
        ns.InitDB()
        assert.is_false(SimpleBlessingBarDB.demo)
    end)
end)

-- Version 5 (ruleset plan 2026-10-18-settings-more, IMPLEMENTATION "Settings, version 5")
describe("settings version 5", function()
    it("migrate a version 4 file to the supply defaults, twice without change", function()
        local ns = addon.load("enUS", { db = { dbVersion = 4, flyoutDir = "FIRST" } })
        local D = ns.D
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.equal(D.DB_VERSION, db.dbVersion)
        assert.is_false(db.autoBuy)
        for _, key in ipairs({ "symbolWarn", "symbolAmount", "goldReserve" }) do
            assert.are.equal(D.NUMBER_DEFAULTS[key].default, db[key], key)
        end
        assert.are.same(D.COLOR_DEFAULTS.symbolWarnColor, db.symbolWarnColor)
        assert.are_not.equal(D.COLOR_DEFAULTS.symbolWarnColor, db.symbolWarnColor)
        assert.are.equal("FIRST", db.flyoutDir)
        local once = copy(db)
        ns.InitDB()
        assert.are.same(once, SimpleBlessingBarDB)
    end)

    it("repair the order: unknown keys and doubles out, missing ones appended", function()
        local ns = addon.load("enUS", { db = { dbVersion = 6, order = { "SALVATION", "BOGUS", "SALVATION", 7 } } })
        local D = ns.D
        ns.InitDB()
        assert.are.same({ "SALVATION", "AURA", "FURY", "BLESSING" }, SimpleBlessingBarDB.order)
        for _, bad in ipairs({ "x", 5 }) do
            ns = addon.load("enUS", { db = { dbVersion = 6, order = bad } })
            ns.InitDB()
            assert.are.same(D.DEFAULT_ORDER, SimpleBlessingBarDB.order)
            assert.are_not.equal(ns.D.DEFAULT_ORDER, SimpleBlessingBarDB.order)
        end
    end)

    it("clamp and repair damaged supply values", function()
        local ns = addon.load("enUS", { db = { dbVersion = 5,
            symbolWarn = "x", symbolAmount = 500, goldReserve = -3, autoBuy = 1,
            symbolZeroColor = { r = 2, g = 0, b = 0, a = 1 },
        } })
        local D = ns.D
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.equal(D.NUMBER_DEFAULTS.symbolWarn.default, db.symbolWarn)
        assert.are.equal(D.NUMBER_DEFAULTS.symbolAmount.max, db.symbolAmount)
        assert.are.equal(0, db.goldReserve)
        assert.is_false(db.autoBuy)
        assert.are.same({ r = 1, g = 0, b = 0, a = 1 }, db.symbolZeroColor)
    end)
end)

-- Version 6 (ruleset plan 2026-10-19-blessing-core, IMPLEMENTATION "Definitions")
describe("settings version 6", function()
    local function v5()
        return { dbVersion = 5, order = { "CLASSES", "AURA", "FURY" },
            classOrder = { "MAGE", "WARRIOR" }, assign = { WARRIOR = "MIGHT" },
            classAntsColor = { r = 0, g = 1, b = 0, a = 1 }, classAntsSpeed = 5 }
    end

    it("migrate a version 5 file: the class block becomes blessing and Salvation, twice without change", function()
        local ns = addon.load("enUS", { db = v5() })
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.equal(ns.D.DB_VERSION, db.dbVersion)
        assert.are.same({ "BLESSING", "SALVATION", "AURA", "FURY" }, db.order)
        assert.are.same({ r = 0, g = 1, b = 0, a = 1 }, db.blessingAntsColor)
        assert.are.equal(5, db.blessingAntsSpeed)
        assert.is_nil(db.classAntsColor)
        assert.is_nil(db.classAntsSpeed)
        assert.is_nil(db.assign)
        assert.is_nil(db.classOrder)
        local once = copy(db)
        ns.InitDB()
        assert.are.same(once, SimpleBlessingBarDB)
    end)

    it("migrate a file without a version", function()
        local saved = v5()
        saved.dbVersion = nil
        local ns = addon.load("enUS", { db = saved })
        ns.InitDB()
        assert.are.same({ "BLESSING", "SALVATION", "AURA", "FURY" }, SimpleBlessingBarDB.order)
        assert.is_nil(SimpleBlessingBarDB.assign)
    end)

    it("leave a version 6 file's blessing ants as they are", function()
        local saved = v5()
        saved.dbVersion = 6
        saved.order = nil
        saved.blessingAntsSpeed = 2
        local ns = addon.load("enUS", { db = saved })
        ns.InitDB()
        assert.are.equal(2, SimpleBlessingBarDB.blessingAntsSpeed)
    end)
end)

-- Version 4 (ruleset plan 2026-10-18-bar-polish, IMPLEMENTATION "Settings, version 4")
describe("settings version 4", function()
    it("migrate a version 3 file: automatic flyouts, the time narrowed, twice without change", function()
        local ns = addon.load("enUS", { db = { dbVersion = 3, flyoutAutoCloseTime = 8, vertical = true } })
        local D = ns.D
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.equal(D.DB_VERSION, db.dbVersion)
        assert.are.equal(D.FLYOUT_DIR_DEFAULT, db.flyoutDir)
        assert.are.equal(D.AUTOCLOSE_MAX, db.flyoutAutoCloseTime)
        assert.is_true(db.vertical)
        local once = copy(db)
        ns.InitDB()
        assert.are.same(once, SimpleBlessingBarDB)
    end)

    it("start a missing auto-close time at the default", function()
        local ns = addon.load("enUS", { db = { dbVersion = 3 } })
        ns.InitDB()
        assert.are.equal(ns.D.FLYOUT_AUTOHIDE, SimpleBlessingBarDB.flyoutAutoCloseTime)
    end)

    it("keep a valid flyout direction and replace an invalid one", function()
        local ns = addon.load("enUS", { db = { dbVersion = 4, flyoutDir = "SECOND" } })
        ns.InitDB()
        assert.are.equal("SECOND", SimpleBlessingBarDB.flyoutDir)
        for _, bad in ipairs({ "UP", 2, true }) do
            ns = addon.load("enUS", { db = { dbVersion = 4, flyoutDir = bad } })
            ns.InitDB()
            assert.are.equal(ns.D.FLYOUT_DIR_DEFAULT, SimpleBlessingBarDB.flyoutDir, tostring(bad))
        end
    end)
end)
