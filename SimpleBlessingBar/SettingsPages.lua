-- SimpleBlessingBar - settings pages
-- The pages of the settings window, built with the helpers of Settings.lua (ns.UI).

local _, ns = ...
if not ns.enabled then return end

local UI = ns.UI

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------
UI.NewPage("TAB_GENERAL")

---------------------------------------------------------------------------
-- Tracking
---------------------------------------------------------------------------
UI.NewPage("TAB_TRACKING")

UI.CreateTabs()
