-- SimpleBlessingBar - static data
-- Spell IDs, layout constants and default settings. Loaded before every other module.

local _, ns = ...

local D = {}
ns.D = D

-- Schema version of SimpleBlessingBarDB; a change to its shape raises it and ships a migration
-- in ns.InitDB() (ruleset: project.md, Data)
D.DB_VERSION = 1
