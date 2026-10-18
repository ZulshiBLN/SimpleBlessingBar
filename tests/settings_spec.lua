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
    it("start with no assignment, the default aura, unlocked and no position", function()
        local ns = addon.load("enUS")
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.same({}, db.assign)
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
        assert.is_table(once.assign)
        ns.InitDB()
        assert.are.same(once, SimpleBlessingBarDB)
    end)

    it("keep valid assignments and drop invalid ones", function()
        local ns = addon.load("enUS", { db = { dbVersion = 2, assign = {
            WARRIOR = "MIGHT",        -- valid
            BOGUS = "MIGHT",          -- no such class
            MAGE = "SANCTUARY",       -- not in the game
            PRIEST = 5,               -- not a family name
        } } })
        ns.InitDB()
        assert.are.same({ WARRIOR = "MIGHT" }, SimpleBlessingBarDB.assign)
    end)

    it("replace a damaged assignment table, aura, lock and position", function()
        local ns = addon.load("enUS", { db = {
            dbVersion = 2, assign = "x", aura = "FOO", locked = "yes",
            point = "CENTER", rel = "CENTER", x = 0 / 0, y = 10,
        } })
        ns.InitDB()
        local db = SimpleBlessingBarDB
        assert.are.same({}, db.assign)
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
        assert.are.same({ WARRIOR = "MIGHT" }, db.assign)
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
