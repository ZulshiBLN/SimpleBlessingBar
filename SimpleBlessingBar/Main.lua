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
    if lang then ns.SetLocale(lang) end

    ns.Print(L.LOADED:format(ns.VERSION))
end)
