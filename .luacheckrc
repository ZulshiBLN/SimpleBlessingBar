-- The globals rule from the ruleset's code.md, made checkable: the addon may
-- write only what the client or the TOC must find by name.
std = "lua51"
max_line_length = false

-- CI installs Lua and LuaRocks into the checkout (.lua/, .luarocks/); their
-- code is not ours to check
exclude_files = { ".lua/**", ".luarocks/**" }

-- WoW's Lua has no file, process or module loading. lua51 would allow them.
not_globals = { "io", "os", "require", "dofile", "loadfile", "module" }

-- Every name the rule allows, including those no code writes yet: the rule is
-- encoded here whole, not grown file by file.
globals = {
    "SimpleBlessingBarDB",
    "SimpleBlessingBarGlobalDB",
    "SLASH_SIMPLEBLESSINGBAR1",
    "SimpleBlessingBar_OnCompartmentClick",
    "SimpleBlessingBar_OnCompartmentEnter",
    "SimpleBlessingBar_OnCompartmentLeave",
}

-- The WoW API the addon reads, listed by hand so a typo or a removed API is
-- reported instead of trusted. SlashCmdList is shared by every addon; only our
-- own entry may be written.
read_globals = {
    "C_AddOns", "C_ClassColor", "C_Item", "C_Spell", "C_Timer", "C_UnitAuras", "CreateFrame",
    "UIParent", "UISpecialFrames", "tinsert",
    "GameTooltip", "GetLocale", "GetNumGroupMembers", "GetNumSubgroupMembers", "GetRaidRosterInfo",
    "InCombatLockdown", "IsInGroup", "IsInRaid", "IsPlayerSpell",
    "RegisterStateDriver", "UnregisterStateDriver", "ReloadUI", "ColorPickerFrame", "CreateColor", "PixelUtil",
    "C_CurrencyInfo", "C_MerchantFrame", "GetMerchantNumItems", "GetMerchantItemID", "GetMerchantItemMaxStack",
    "BuyMerchantItem", "GetMoney", "GetTime", "GetCursorPosition", "IsMouseButtonDown", "LOCALIZED_CLASS_NAMES_MALE",
    "Minimap", "Settings", "UnitFullName", "GetRealmName", "UnitLevel", "GetBuildInfo", "date", "issecretvalue",
    "BugGrabber", "UnitGroupRolesAssigned", "UnitName", "UnitGUID",
    "UnitClass", "UnitExists", "UnitIsConnected", "UnitIsDeadOrGhost", "UnitIsUnit", "UnitIsVisible",
    SlashCmdList = { fields = { SIMPLEBLESSINGBAR = { read_only = false } } },
}

-- Specs run in plain Lua 5.1 under busted, where file access is how they read
-- the addon's sources.
-- Checked together with the mock (as `luacheck .` and CI do), the mock's top-level
-- definitions count as defined here too; these lists keep a spec clean when it is
-- checked alone.
files["tests/"] = {
    std = "lua51+busted",
    -- Specs build the mocked world by changing STATE's fields
    globals = { "STATE" },
    read_globals = {
        "io", "require", "loadfile",
        -- What tests/helpers/mock.lua provides to drive the mocked client
        "FIRE", "CHAT", "RUNSCRIPT", "RUNCLICK", "RUNTIMERS", "TICK", "NEWOBJ", "MENU", "UIParent",
    },
}

-- The mock *is* the WoW API: defining client globals is its whole job.
files["tests/helpers/mock.lua"] = {
    std = "lua51",
    allow_defined_top = true,
    read_globals = { "io" },
    ignore = { "111", "112", "121", "122", "131", "212" },
}
