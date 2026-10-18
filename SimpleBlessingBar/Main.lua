-- SimpleBlessingBar - startup

local _, ns = ...
if not ns.enabled then return end

local L = ns.L

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    ns.InitDB()
    -- Saved language choice (account-wide), otherwise the client language. Applied before any
    -- chat output, so every message already uses the chosen language.
    local lang = SimpleBlessingBarGlobalDB.language
    if lang then ns.ApplyLanguage(lang) end

    ns.InitBar()
    ns.ApplyMinimapButton()
    ns.RegisterOptionsPanel()
    ns.Print(L.LOADED:format(ns.VERSION))
end)

---------------------------------------------------------------------------
-- Chat commands
---------------------------------------------------------------------------
SLASH_SIMPLEBLESSINGBAR1 = "/sbb"

-- In the order /sbb help lists them
local COMMANDS = {
    { cmd = "",      desc = "CMD_OPEN" },
    { cmd = "help",  desc = "CMD_HELP" },
    { cmd = "lock",  desc = "CMD_LOCK" },
    { cmd = "reset", desc = "CMD_RESET" },
    { cmd = "bug",   desc = "CMD_BUG" },
}

local function PrintHelp()
    ns.Print(L.HELP_HEADER)
    for _, c in ipairs(COMMANDS) do
        local full = c.cmd == "" and "/sbb" or ("/sbb " .. c.cmd)
        print("   |cffffd100" .. full .. "|r - " .. L[c.desc])
    end
end

SlashCmdList.SIMPLEBLESSINGBAR = function(msg)
    local db = SimpleBlessingBarDB
    if type(db) ~= "table" then return end -- before PLAYER_LOGIN
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" then
        ns.ToggleSettings()
    elseif msg == "help" then
        PrintHelp()
    elseif msg == "lock" then
        ns.ToggleLock()
        ns.Print(db.locked and L.LOCKED or L.UNLOCKED)
    elseif msg == "reset" then
        -- The bar holds secure buttons and cannot move in combat
        if InCombatLockdown() then ns.Print(L.NOT_IN_COMBAT) return end
        db.point, db.rel, db.x, db.y = nil, nil, nil, nil
        ns.LoadPosition()
        ns.Print(L.POS_RESET)
    elseif msg == "bug" then
        ns.OpenBugReport()
    else
        ns.Print(L.CMD_UNKNOWN:format("|cffffd100/sbb help|r"))
    end
end
