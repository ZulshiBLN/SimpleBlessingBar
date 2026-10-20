-- SmartBlessingBar - entry points: minimap button, AddOn compartment, options entry
-- As in SimpleConjureBar (ruleset plan 2026-10-18-settings-more). The minimap button is built
-- without a library (project.md): left click = settings, right click = lock, drag = move it
-- around the minimap.

local ADDON_NAME, ns = ...
if not ns.enabled then return end

local L = ns.L
local SetL = ns.SetL

local db
ns.OnDBReady(function(d) db = d end)

-- The icon the TOC gives the addon list, read from there: one fact, one place
local ICON = C_AddOns.GetAddOnMetadata(ADDON_NAME, "IconTexture")

local function ToggleLockWithMessage()
    ns.ToggleLock()
    ns.Print(db.locked and L.LOCKED or L.UNLOCKED)
end

local function ShowEntryTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetText("SmartBlessingBar |cffffffffv" .. ns.VERSION .. "|r")
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L.LEFTCLICK, L.SETTINGS, 0, 1, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine(L.RIGHTCLICK, db.locked and L.UNLOCK or L.LOCK, 0, 1, 0, 1, 1, 1)
    if anchor == "ANCHOR_LEFT" then -- only the minimap button opens the Priorities tab and can be dragged
        GameTooltip:AddDoubleLine(L.MIDDLECLICK, L.TAB_PRIORITIES, 0, 1, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.DRAG, L.MOVE, 0, 1, 0, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function Click(button)
    if button == "RightButton" then ToggleLockWithMessage() else ns.ToggleSettings() end
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local minimapBtn = CreateFrame("Button", "SmartBlessingBarMinimapButton", Minimap)
ns.minimapButton = minimapBtn
minimapBtn:SetSize(31, 31)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)
minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

do
    local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    minimapBtn.icon = icon

    local border = minimapBtn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
end

-- On a circle around the minimap
local function PlaceMinimapButton()
    local angle = math.rad(db.minimapAngle)
    local radius = (Minimap:GetWidth() / 2) + 10
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns.ApplyMinimapButton()
    if db.hideMinimap then minimapBtn:Hide() else minimapBtn:Show() end
    PlaceMinimapButton()
end

local function OnMinimapDrag()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    PlaceMinimapButton()
end
minimapBtn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnMinimapDrag) end)
minimapBtn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

-- A middle click opens the settings on the Priorities tab, with the overview; open on that
-- tab, it closes them. The AddOn compartment keeps its two clicks (ruleset plan
-- 2026-10-19-priorities).
local function PrioritiesClick()
    if InCombatLockdown() then ns.Print(L.NOT_IN_COMBAT) return end
    if ns.SettingsPageShown("TAB_PRIORITIES") then ns.CloseSettings() else ns.OpenSettingsOn("TAB_PRIORITIES") end
end
minimapBtn:SetScript("OnClick", function(_, button)
    if button == "MiddleButton" then PrioritiesClick() else Click(button) end
end)
minimapBtn:SetScript("OnEnter", function(self) ShowEntryTooltip(self, "ANCHOR_LEFT") end)
minimapBtn:SetScript("OnLeave", ns.HideTooltip)

---------------------------------------------------------------------------
-- AddOn compartment: Core.lua's globals call these
---------------------------------------------------------------------------
function ns.CompartmentClick(_, button) Click(button) end
function ns.CompartmentEnter(_, menuButton) ShowEntryTooltip(menuButton, "ANCHOR_RIGHT") end
function ns.CompartmentLeave() ns.HideTooltip() end

---------------------------------------------------------------------------
-- Entry in the client's options (Options > AddOns): a page with a button that opens our window
---------------------------------------------------------------------------
function ns.RegisterOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "SmartBlessingBar"

    local head = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    head:SetTextColor(1, 0.82, 0) -- Blizzard gold
    head:SetPoint("TOP", panel, "TOP", 0, -120)
    head:SetText("SmartBlessingBar")

    local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    ver:SetPoint("TOP", head, "BOTTOM", 0, -10)
    SetL(ver, "VERSION", ns.VERSION)

    local helpHint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    helpHint:SetPoint("TOP", ver, "BOTTOM", 0, -18)
    SetL(helpHint, "HELP_HINT", "|cffffd100/sbb help|r")

    local access = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    access:SetPoint("TOP", helpHint, "BOTTOM", 0, -6)
    SetL(access, "ACCESS_OPTIONS", "|cffffd100/sbb|r")

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    SetL(open, "OPEN_SETTINGS")
    local function FitOpen()
        open:SetSize(math.max(160, open:GetFontString():GetStringWidth() + 40), 28)
    end
    FitOpen()
    ns.OnLanguageChanged(FitOpen)
    open:SetPoint("TOP", access, "BOTTOM", 0, -18)
    open:SetScript("OnClick", function() ns.OpenSettings(true) end)
    ns.optionsOpenButton = open

    local category = Settings.RegisterCanvasLayoutCategory(panel, "SmartBlessingBar")
    Settings.RegisterAddOnCategory(category)
end
