-- SimpleBlessingBar - settings window framework
-- The window, its layout system and the reusable widgets, after SimpleConjureBar's. The pages
-- themselves are built in SettingsPages.lua with the helpers exported as ns.UI.
--
-- Layout system: every widget registers
--   refreshers - load the values from the settings into the widget (on show and language change)
--   measures   - return the content width the widget needs (texts differ per language)
--   stretchers - fit the widget to the final content width
-- so the window always fits its content in every language.

local _, ns = ...
if not ns.enabled then return end

local L = ns.L
local SetL = ns.SetL

local db
ns.OnDBReady(function(d) db = d end)

local UI = {}
ns.UI = UI

local settings = CreateFrame("Frame", "SimpleBlessingBarSettings", UIParent, "BackdropTemplate")
UI.window = settings
settings:SetSize(300, 290)
settings:SetPoint("CENTER")
settings:SetFrameStrata("DIALOG")
settings:SetMovable(true)
settings:EnableMouse(true)
settings:RegisterForDrag("LeftButton")
settings:SetScript("OnDragStart", settings.StartMoving)
settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
settings:SetClampedToScreen(true)
settings:Hide()
settings:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
tinsert(UISpecialFrames, "SimpleBlessingBarSettings") -- closes with Escape

-- The dialog border is about 12 px wide, plus 10 px space to the content
local INSET = 22
local MIN_W = 240
local TOP_Y = -84 -- below the title and the tabs
UI.INSET = INSET

local refreshers, measures, stretchers = {}, {}, {}
UI.refreshers, UI.measures, UI.stretchers = refreshers, measures, stretchers

---------------------------------------------------------------------------
-- Pages (tabs): every page has its own placement cursor
---------------------------------------------------------------------------
local pages, page = {}, nil
UI.pages = pages

function UI.NewPage(titleKey)
    local pg = CreateFrame("Frame", nil, settings)
    pg:SetPoint("TOPLEFT")
    pg:SetPoint("BOTTOMRIGHT")
    pg:Hide()
    pg.cursorY, pg.titleKey = TOP_Y, titleKey
    pages[#pages + 1] = pg
    page = pg
    return pg
end
function UI.CurrentPage() return page end

-- Reserves vertical space on the current page and returns its top offset
function UI.Place(height, gap)
    local y = page.cursorY
    page.cursorY = page.cursorY - height - (gap or 6)
    return y
end

---------------------------------------------------------------------------
-- Title with version, close button
---------------------------------------------------------------------------
local title = settings:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetText("SimpleBlessingBar")

-- Version slightly smaller and white right after the title
local titleVersion = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
titleVersion:SetText("v" .. ns.VERSION)
titleVersion:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)

-- Center title and version together
local function PlaceTitle()
    local shift = (titleVersion:GetStringWidth() + 6) / 2
    title:ClearAllPoints()
    title:SetPoint("TOP", settings, "TOP", -math.floor(shift), -18)
end
PlaceTitle()
-- Leave room for the close button on both sides of the centered title
measures[#measures + 1] = function()
    PlaceTitle()
    return title:GetStringWidth() + 6 + titleVersion:GetStringWidth() + 2 * 34
end

local close = CreateFrame("Button", nil, settings, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

---------------------------------------------------------------------------
-- Tabs and window layout (called by SettingsPages.lua once all pages exist)
---------------------------------------------------------------------------
local tabs, activePage = {}, 1
UI.tabs = tabs

local function ShowPage(i)
    activePage = i
    for k, pg in ipairs(pages) do
        local tb = tabs[k]
        if k == i then
            pg:Show()
            tb:LockHighlight()
            tb:GetFontString():SetTextColor(1, 0.82, 0)
        else
            pg:Hide()
            tb:UnlockHighlight()
            tb:GetFontString():SetTextColor(1, 1, 1)
        end
    end
end

-- Tabs next to each other, width by text
local function ArrangeTabs()
    local x = INSET
    for _, tb in ipairs(tabs) do
        tb:SetWidth(tb:GetFontString():GetStringWidth() + 24)
        tb:ClearAllPoints()
        tb:SetPoint("TOPLEFT", settings, "TOPLEFT", x, -46)
        x = x + tb:GetWidth() + 4
    end
    return x - 4 - INSET
end

-- Width and height follow the content (the tallest page sets the height)
local function LayoutSettings()
    local contentW = MIN_W
    for _, m in ipairs(measures) do contentW = math.max(contentW, math.ceil(m())) end
    for _, st in ipairs(stretchers) do st(contentW) end
    settings:SetWidth(contentW + 2 * INSET)
    local lowest = 0
    for _, pg in ipairs(pages) do lowest = math.min(lowest, pg.cursorY) end
    -- cursorY points below the last element; replace the last gap with the border
    settings:SetHeight(-lowest - 4 + INSET)
end

local function RefreshAll()
    for _, f in ipairs(refreshers) do f() end
    LayoutSettings()
    ShowPage(activePage)
end

function UI.CreateTabs()
    for i, pg in ipairs(pages) do
        local tb = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
        tb:SetHeight(22)
        SetL(tb, pg.titleKey)
        tb:SetScript("OnClick", function() ShowPage(i) end)
        tabs[i] = tb
    end
    measures[#measures + 1] = ArrangeTabs
end

-- Reloads all values into an open window (after chat commands)
function ns.RefreshSettingsWindow()
    if settings:IsShown() then
        for _, f in ipairs(refreshers) do f() end
    end
end

ns.OnLanguageChanged(function()
    ArrangeTabs()
    if settings:IsShown() then RefreshAll() end
end)

---------------------------------------------------------------------------
-- Show / hide, combat handling
---------------------------------------------------------------------------
settings:SetScript("OnShow", function()
    -- Settings change the protected bar, so the window does not open in combat
    if InCombatLockdown() or not db then
        settings:Hide()
        if InCombatLockdown() then ns.Print(L.MENU_COMBAT) end
        return
    end
    RefreshAll()
end)

function ns.ToggleSettings()
    if settings:IsShown() then settings:Hide() else settings:Show() end
end

-- Combat start: close the window, and reopen it afterwards if combat closed it
do
    local reopenAfterCombat = false
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if settings:IsShown() then
                reopenAfterCombat = true
                settings:Hide()
            end
        elseif reopenAfterCombat then
            reopenAfterCombat = false
            settings:Show()
        end
    end)
end
