-- SimpleBlessingBar - core
-- Class check, chat output and saved variables. Every other module builds on this file.

local ADDON_NAME, ns = ...
local D = ns.D

-- The addon is paladin-only. Every later module checks this flag and stops loading otherwise.
local _, playerClass = UnitClass("player")
ns.enabled = (playerClass == "PALADIN")
if not ns.enabled then return end

ns.ADDON_NAME = ADDON_NAME
ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------
function ns.Print(msg)
    print("|cfff58cbaSimpleBlessingBar|r: " .. msg)
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
local db
local dbCallbacks = {}

-- Modules keep their own local reference to the settings table; it exists after PLAYER_LOGIN.
function ns.OnDBReady(fn)
    dbCallbacks[#dbCallbacks + 1] = fn
    if db then fn(db) end
end

-- Saved variables are plain files that can be edited or damaged, so every value is checked
-- before anything reads it.
function ns.InitDB()
    if type(SimpleBlessingBarDB) ~= "table" then SimpleBlessingBarDB = {} end
    if type(SimpleBlessingBarGlobalDB) ~= "table" then SimpleBlessingBarGlobalDB = {} end
    db = SimpleBlessingBarDB

    local lang = SimpleBlessingBarGlobalDB.language
    if lang ~= nil and not ns.locales[lang] then
        SimpleBlessingBarGlobalDB.language = nil -- unknown language code
    end

    db.dbVersion = D.DB_VERSION

    for _, fn in ipairs(dbCallbacks) do fn(db) end
end
