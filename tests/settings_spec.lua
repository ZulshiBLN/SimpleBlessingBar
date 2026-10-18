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
