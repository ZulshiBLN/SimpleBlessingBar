-- SimpleBlessingBar - static data
-- Spell IDs, layout constants and default settings. Loaded before every other module.
-- IDs are the Classic Era IDs, checked on WoW Forever 1.60.1.70450 (ruleset research
-- 2026-10-18-paladin-facts). Blessing of Sanctuary does not exist there and is left out.

local _, ns = ...

local D = {}
ns.D = D

-- Schema version of SimpleBlessingBarDB; a change to its shape raises it and ships a migration
-- in ns.InitDB() (ruleset: project.md, Data)
D.DB_VERSION = 3

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

-- Demo mode's sample counts per class; a 0 shows a class whose members all have the blessing
D.DEMO_COUNTS = {
    WARRIOR = 2, PALADIN = 0, HUNTER = 1, ROGUE = 3, PRIEST = 1, SHAMAN = 2, MAGE = 0, WARLOCK = 4, DRUID = 1,
}

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

-- Where a flyout opens, per direction, as in SimpleConjureBar: the flyout's anchor against its
-- main button, the side its icons start from and their step, the arrow's anchor and rotation
D.FLY_LAYOUT = {
    UP    = { fly = { "BOTTOM", "TOP", 0, 6 },  child = "BOTTOM", dx = 0,  dy = 1,  arrow = { "BOTTOM", "TOP", 0, -6 }, rot = 0 },
    DOWN  = { fly = { "TOP", "BOTTOM", 0, -6 }, child = "TOP",    dx = 0,  dy = -1, arrow = { "TOP", "BOTTOM", 0, 6 },  rot = math.pi },
    RIGHT = { fly = { "LEFT", "RIGHT", 6, 0 },  child = "LEFT",   dx = 1,  dy = 0,  arrow = { "LEFT", "RIGHT", -6, 0 }, rot = -math.pi / 2 },
    LEFT  = { fly = { "RIGHT", "LEFT", -6, 0 }, child = "RIGHT",  dx = -1, dy = 0,  arrow = { "RIGHT", "LEFT", 6, 0 },  rot = math.pi / 2 },
}

-- Seconds an open flyout stays once the mouse has left it and its button: the default of the
-- setting, and what the open snippet uses before the first refresh (Michel, 2026-10-18)
D.FLYOUT_AUTOHIDE = 2

-- "Marching ants" highlight, as in SimpleConjureBar: Blizzard flip book with 22 frames of
-- 48 px in a 256 px texture, desaturated and tinted
D.ANTS_TEX    = "Interface\\SpellActivationOverlay\\IconAlertAnts"
D.ANTS_FRAMES = 22
D.ANTS_COLS   = 5
D.ANTS_CELL   = 48 / 256
-- Seconds per frame for the speeds 1-5 of the settings; 3 is SimpleConjureBar's default
D.ANTS_STEPS  = { 0.04, 0.02, 0.01, 0.0075, 0.005 }
D.ANTS_COLOR  = { r = 1, g = 0.82, b = 0.2, a = 1 } -- SimpleConjureBar's default gold

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
D.DEFAULT_AURA = "DEVOTION"

-- Settings of version 3 with their defaults; numbers carry their range. Colors are copied into
-- the settings, never referenced, so nothing written to the settings changes these tables.
D.SCALE_MIN, D.SCALE_MAX = 0.5, 2.0
D.ANTS_SPEED_MIN, D.ANTS_SPEED_MAX = 1, 5
D.ANTS_SPEED_DEFAULT = 3
D.AUTOCLOSE_MIN, D.AUTOCLOSE_MAX = 1, 10
D.BOOL_DEFAULTS = {
    showBorder = true, vertical = false, growRev = false, hideCombat = false,
    showAura = true, showFury = true, flyoutAutoClose = true,
}
D.COLOR_DEFAULTS = {
    bg            = D.BG_COLOR,
    auraAntsColor = D.ANTS_COLOR,
    furyAntsColor = D.ANTS_COLOR,
    countColor    = { r = 1, g = 1, b = 1, a = 1 },
}
D.NUMBER_DEFAULTS = {
    scale               = { default = 1, min = D.SCALE_MIN, max = D.SCALE_MAX },
    auraAntsSpeed       = { default = D.ANTS_SPEED_DEFAULT, min = D.ANTS_SPEED_MIN, max = D.ANTS_SPEED_MAX, integer = true },
    furyAntsSpeed       = { default = D.ANTS_SPEED_DEFAULT, min = D.ANTS_SPEED_MIN, max = D.ANTS_SPEED_MAX, integer = true },
    flyoutAutoCloseTime = { default = D.FLYOUT_AUTOHIDE, min = D.AUTOCLOSE_MIN, max = D.AUTOCLOSE_MAX, integer = true },
}
