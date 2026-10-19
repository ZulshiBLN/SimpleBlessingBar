-- SimpleBlessingBar - the overview window
-- Members under their role, the blessings and Salvation they carry, mine bordered, the one
-- this paladin would give next faint (ruleset plan 2026-10-19-overview). Built out of combat
-- from the planner's reads, on every refresh while shown.

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings

local INSET, TITLE_H = 22, 40
local ROW_H, HEADER_H, ICON, ICON_GAP, NAME_W = 20, 18, 16, 3, 120
local SLOTS = { "MIGHT", "WISDOM", "KINGS", "LIGHT", "SALVATION" } -- D.BLESSING_ORDER, Salvation last
local COL_W = NAME_W + #SLOTS * (ICON + ICON_GAP) + 10
local ONE_COLUMN_MAX = 20

local frame = CreateFrame("Frame", "SimpleBlessingBarOverview", UIParent, "BackdropTemplate")
ns.overview = frame
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetClampedToScreen(true)
frame:SetDontSavePosition(true) -- its place lasts until /reload, the client keeps nothing
frame:Hide()
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
tinsert(UISpecialFrames, "SimpleBlessingBarOverview") -- closes with Escape

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -18)
ns.SetL(title, "OVERVIEW")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

frame.rows, frame.headers, frame.footer = {}, {}, {}

local FOOTER_H = 16

-- A footer line: the name, then what was given and how often, in D.BLESSING_ORDER, Salvation
-- last; "-" for nothing
local function FooterText(name, counts)
    local pieces = {}
    for _, key in ipairs(SLOTS) do
        local n = counts[key]
        if n then
            local label = key == "SALVATION"
                and ns.LocalName(C_Spell.GetSpellName(D.SALVATION), "SALVATION") or B.FamilyName(key)
            pieces[#pieces + 1] = L.OV_COUNT:format(label, n)
        end
    end
    return L.OV_LINE:format(name, #pieces > 0 and table.concat(pieces, L.OV_SEP) or L.OV_NONE)
end

-- The member's name without Forever's second name; a class name in demo mode
local function Name(d)
    if ns.IsDemo() then return ns.LocalName(LOCALIZED_CLASS_NAMES_MALE[d.class], "CLASS_" .. d.class) end
    local name = (UnitName(d.unit))
    return d.hand and (name .. " *") or name
end

-- An icon's tooltip: the game's, then who gave it and the minutes left
local function ShowIconTooltip(slot)
    GameTooltip:SetOwner(slot, "ANCHOR_TOP")
    GameTooltip:SetSpellByID(slot.spell)
    local c = slot.carried
    if c then
        local giver = c.source and B.InGroup(c.source)
        GameTooltip:AddLine(L.OV_FROM:format(giver and (UnitName(giver)) or L.OV_ANOTHER), 1, 1, 1)
        if c.expires > 0 then
            GameTooltip:AddLine(L.OV_LEFT:format(math.ceil((c.expires - GetTime()) / 60)), 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function NewRow(i)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(COL_W, ROW_H)
    row:EnableMouse(true)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetWidth(NAME_W - 4)
    row.name:SetJustifyH("LEFT")
    -- A right click opens the role menu for this member; not in demo mode, where every row
    -- is the player
    row:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" or ns.IsDemo() or InCombatLockdown() then return end
        ns.OpenRoleMenu(self, self.unit)
    end)
    row.slots = {}
    for s, family in ipairs(SLOTS) do
        local slot = CreateFrame("Frame", nil, row)
        slot:SetSize(ICON, ICON)
        slot:SetPoint("LEFT", NAME_W + (s - 1) * (ICON + ICON_GAP), 0)
        slot.family = family
        slot.border = slot:CreateTexture(nil, "BACKGROUND")
        slot.border:SetPoint("TOPLEFT", -2, 2)
        slot.border:SetPoint("BOTTOMRIGHT", 2, -2)
        slot.border:SetColorTexture(1, 0.82, 0, 1)
        slot.tex = slot:CreateTexture(nil, "ARTWORK")
        slot.tex:SetAllPoints()
        slot.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        slot.plus = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        slot.plus:SetPoint("BOTTOMRIGHT", 2, -2)
        slot:EnableMouse(true)
        slot:SetScript("OnEnter", ShowIconTooltip)
        slot:SetScript("OnLeave", ns.HideTooltip)
        row.slots[s] = slot
    end
    frame.rows[i] = row
    return row
end

local function NewHeader(i)
    local h = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetJustifyH("LEFT")
    frame.headers[i] = h
    return h
end

-- Writes a member into a row: his name, then per slot what he carries, or the faint next one
-- in its family's place
local function FillRow(row, d)
    row.unit, row.role, row.greyed = d.unit, d.role, d.greyed
    row.name:SetText(Name(d))
    row.name:SetAlpha(d.greyed and 0.4 or 1)
    for _, slot in ipairs(row.slots) do
        local carried, faint = d.carried[slot.family], d.next and d.next.family == slot.family
        slot.carried, slot.faint, slot.mine = nil, nil, nil
        if faint then
            slot.spell, slot.faint = d.next.spell, true
        elseif carried then
            slot.spell, slot.carried, slot.mine = carried.spell, carried, carried.mine
        end
        if faint or carried then
            slot.tex:SetTexture(C_Spell.GetSpellTexture(slot.spell))
            slot.tex:SetAlpha(faint and 0.35 or (d.greyed and 0.4 or 1))
            slot.border:SetShown(slot.mine == true)
            slot.plus:SetText(faint and "+" or "")
            slot:Show()
        else
            slot:Hide()
        end
    end
    row:Show()
end

-- Sections in role order; up to 20 members one column, from 21 the first half on the left, a
-- section split across the columns repeating its header
local function Build()
    local members = B.Overview()
    local byRole = {}
    for _, d in ipairs(members) do
        byRole[d.role] = byRole[d.role] or {}
        table.insert(byRole[d.role], d)
    end
    local leftCount = #members > ONE_COLUMN_MAX and math.ceil(#members / 2) or #members

    local nRows, nHeaders, placed = 0, 0, 0
    local column, y, height = 1, 0, 0
    local function Header(role)
        nHeaders = nHeaders + 1
        local h = frame.headers[nHeaders] or NewHeader(nHeaders)
        h.role, h.column = role, column
        h:SetText(L["ROLE_" .. role])
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", INSET + (column - 1) * COL_W, -TITLE_H - y)
        h:Show()
        y = y + HEADER_H
    end
    for _, role in ipairs(D.ROLES) do
        local list = byRole[role]
        if list then
            Header(role)
            for _, d in ipairs(list) do
                if placed == leftCount then
                    height = math.max(height, y)
                    column, y = 2, 0
                    Header(role)
                end
                nRows = nRows + 1
                local row = frame.rows[nRows] or NewRow(nRows)
                row.column = column
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", INSET + (column - 1) * COL_W, -TITLE_H - y)
                FillRow(row, d)
                y = y + ROW_H
                placed = placed + 1
            end
        end
    end
    for i = nRows + 1, #frame.rows do frame.rows[i]:Hide() end
    for i = nHeaders + 1, #frame.headers do frame.headers[i]:Hide() end
    height = math.max(height, y)

    -- The footer: per paladin in the group, then Others if any; none in demo mode
    local texts = {}
    if not ns.IsDemo() then
        local lines, others = B.Footer(members)
        for _, l in ipairs(lines) do texts[#texts + 1] = FooterText((UnitName(l.unit)), l.counts) end
        if next(others) then texts[#texts + 1] = FooterText(L.OV_OTHERS, others) end
    end
    height = height + (#texts > 0 and 8 or 0)
    for i, text in ipairs(texts) do
        local f = frame.footer[i]
        if not f then
            f = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f:SetJustifyH("LEFT")
            frame.footer[i] = f
        end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", INSET, -TITLE_H - height)
        f:SetText(text)
        f:Show()
        height = height + FOOTER_H
    end
    for i = #texts + 1, #frame.footer do frame.footer[i]:Hide() end
    frame:SetSize(2 * INSET + column * COL_W, TITLE_H + height + INSET)
end

frame:SetScript("OnShow", Build)
table.insert(ns.onRefresh, function()
    if frame:IsShown() then Build() end
end)

-- The first opening after /reload is centred, or right of the settings window while that is
-- shown; later ones keep where it was left (Michel, 2026-10-19)
local positioned = false
function ns.ToggleOverview()
    if frame:IsShown() then frame:Hide() return end
    if not positioned then
        positioned = true
        frame:ClearAllPoints()
        local settings = ns.UI and ns.UI.window
        if settings and settings:IsShown() then
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", settings:GetRight() + 8, settings:GetTop())
        else
            frame:SetPoint("CENTER")
        end
    end
    frame:Show()
end

-- From a chat command or the minimap button: in combat it says why nothing opens
function ns.ToggleOverviewOrSay()
    if InCombatLockdown() then ns.Print(L.NOT_IN_COMBAT) return end
    ns.ToggleOverview()
end

-- Combat start closes the window; combat end opens it again if combat closed it
do
    local reopenAfterCombat = false
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if frame:IsShown() then
                reopenAfterCombat = true
                frame:Hide()
            end
        elseif reopenAfterCombat then
            reopenAfterCombat = false
            frame:Show()
        end
    end)
end
