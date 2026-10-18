-- SimpleBlessingBar - static data
-- Spell IDs, layout constants and default settings. Loaded before every other module.
-- IDs are the Classic Era IDs, checked on WoW Forever 1.60.1.70450 (ruleset research
-- 2026-10-18-paladin-facts). Blessing of Sanctuary does not exist there and is left out.

local _, ns = ...

local D = {}
ns.D = D

-- Schema version of SimpleBlessingBarDB; a change to its shape raises it and ships a migration
-- in ns.InitDB() (ruleset: project.md, Data)
D.DB_VERSION = 2

---------------------------------------------------------------------------
-- Spells, lowest rank first. IDs do not rise with rank (Devotion Aura rank 2 is 10290,
-- rank 3 is 643), so code walks these lists and never compares IDs.
---------------------------------------------------------------------------
D.BLESSINGS = {
    MIGHT     = { normal = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, greater = { 25782, 25916 } },
    WISDOM    = { normal = { 19742, 19850, 19852, 19853, 19854, 25290 }, greater = { 25894, 25918 } },
    KINGS     = { normal = { 20217 }, greater = { 25898 } },
    -- The normal Salvation reads "target party member" in game; Mass Salvation names the
    -- whole raid or group. The addon limits only the normal one to the paladin's party.
    SALVATION = { normal = { 1038 }, greater = { 25895 }, normalPartyOnly = true },
    LIGHT     = { normal = { 19977, 19978, 19979 }, greater = { 25890 } },
}
D.BLESSING_ORDER = { "MIGHT", "WISDOM", "KINGS", "SALVATION", "LIGHT" }

D.AURAS = {
    DEVOTION      = { 465, 10290, 643, 10291, 1032, 10292, 10293 },
    RETRIBUTION   = { 7294, 10298, 10299, 10300, 10301 },
    CONCENTRATION = { 19746 },
    SHADOW        = { 19876, 19895, 19896 },
    FROST         = { 19888, 19897, 19898 },
    FIRE          = { 19891, 19899, 19900 },
    SANCTITY      = { 20218 },
}
D.AURA_ORDER = { "DEVOTION", "RETRIBUTION", "CONCENTRATION", "SHADOW", "FROST", "FIRE", "SANCTITY" }

D.RIGHTEOUS_FURY = 25780

-- Reagent of every Greater Blessing
D.SYMBOL_OF_KINGS = 21177

-- Class buttons appear in this order, each only while the class is in the group
D.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

---------------------------------------------------------------------------
-- Look: SimpleConjureBar's, so both addons read as one family
---------------------------------------------------------------------------
D.SIZE, D.GAP, D.PAD = 36, 4, 7 -- button size, gap between buttons, bar padding
D.BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
D.BG_COLOR     = { r = 0, g = 0, b = 0, a = 0.6 }       -- bar and flyout background
D.BORDER_COLOR = { r = 0.4, g = 0.4, b = 0.4, a = 0.8 }
D.HANDLE_UNLOCKED = { r = 0.41, g = 0.8, b = 0.94, a = 0.6 }
D.HANDLE_LOCKED   = { r = 0.9, g = 0.25, b = 0.2, a = 0.6 }

-- Seconds an open flyout stays once the mouse has left it and its button. Fixed until a
-- settings window offers the switch and the time (Michel, 2026-10-18).
D.FLYOUT_AUTOHIDE = 2

-- "Marching ants" highlight, as in SimpleConjureBar: Blizzard flip book with 22 frames of
-- 48 px in a 256 px texture, desaturated and tinted
D.ANTS_TEX    = "Interface\\SpellActivationOverlay\\IconAlertAnts"
D.ANTS_FRAMES = 22
D.ANTS_COLS   = 5
D.ANTS_CELL   = 48 / 256
D.ANTS_STEP   = 0.01                            -- seconds per frame: SimpleConjureBar's default
D.ANTS_COLOR  = { r = 1, g = 0.82, b = 0.2, a = 1 } -- SimpleConjureBar's default gold

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
D.DEFAULT_AURA = "DEVOTION"
