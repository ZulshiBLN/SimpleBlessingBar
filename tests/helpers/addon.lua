-- Loads the addon as the client does: the mocked WoW API first, then every
-- file the TOC lists, in the TOC's order, each called with the addon's name
-- and one shared namespace. The file list is read from the TOC, never retyped.
local M = {}

local ADDON = "SimpleBlessingBar"
M.NAME = ADDON

function M.read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

-- The Lua files of the TOC, in load order.
function M.tocFiles()
    local files = {}
    for line in M.read(ADDON .. "/" .. ADDON .. ".toc"):gmatch("[^\r\n]+") do
        if not line:match("^%s*#") and line:match("%S") then
            files[#files + 1] = line:match("^%s*(.-)%s*$")
        end
    end
    return files
end

-- A fresh mocked client with the addon loaded; `locale` is what GetLocale
-- answers. `world` may set `class` and the saved variables `db` and
-- `globalDB` as the client hands them over, and the STATE fields `units`,
-- `group`, `known`, `bags` and `combat` (see mock.lua). They are set here,
-- not in a spec: busted gives each spec file its own globals, which the
-- addon never sees. A spec may change STATE's fields later - the table is
-- shared. `units.player` gets the class if it has none.
-- Returns the addon's namespace.
function M.load(locale, world)
    world = world or {}
    assert(loadfile("tests/helpers/mock.lua"))()
    STATE.locale = locale or "deDE"
    STATE.class = world.class or STATE.class
    for _, key in ipairs({ "units", "group", "known", "bags", "combat" }) do
        if world[key] ~= nil then STATE[key] = world[key] end
    end
    if world.bugGrabber == false then BugGrabber = nil end
    STATE.units.player = STATE.units.player or {}
    STATE.units.player.class = STATE.units.player.class or STATE.class
    SimpleBlessingBarDB, SimpleBlessingBarGlobalDB = world.db, world.globalDB
    local ns = {}
    for _, file in ipairs(M.tocFiles()) do
        local chunk = assert(loadstring(M.read(ADDON .. "/" .. file), "@" .. ADDON .. "/" .. file))
        chunk(ADDON, ns)
    end
    return ns
end

-- `world` with the player's own Paladin list starting with Might, the order the planner's
-- specs were written against: they test the planner, not the class defaults (ruleset plan
-- 2026-10-20-class-defaults moved the Paladin default to Kings first). A saved file of the
-- world's own is kept.
function M.mightFirst(world)
    world = world or {}
    world.db = world.db or { dbVersion = 8,
        classLists = { PALADIN = { order = { "MIGHT", "KINGS", "LIGHT", "WISDOM" }, off = {} } } }
    return world
end

return M
