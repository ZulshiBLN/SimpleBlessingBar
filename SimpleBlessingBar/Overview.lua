-- SimpleBlessingBar - the overview, at the foot of the Priorities tab
-- Members sorted by class in two columns, names in class colour, a paladin's aura, the
-- blessings and Salvation they carry, mine bordered, the one this paladin would give next
-- faint (ruleset plans 2026-10-19-overview, 2026-10-19-priorities, 2026-10-19-tab-layout).
-- Built out of combat from the planner's reads, when the tab is shown, on every refresh while
-- it is and when the window's width changes. Loaded after SettingsPages.lua, which makes the
-- scroll frame it fills.

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings

local ROW_H, ICON, ICON_GAP = 20, 16, 3
local SLOTS = { "MIGHT", "WISDOM", "KINGS", "LIGHT", "SALVATION" } -- D.BLESSING_ORDER, Salvation last
-- A row (Michel): 10 px, the name, 10 px, the aura, 5 px, the slots, 10 px to the column's edge
local MARGIN, NAME_GAP, AURA_GAP = 10, 10, 5
local SLOTS_W = #SLOTS * (ICON + ICON_GAP)
local FIXED_W = MARGIN + NAME_GAP + ICON + AURA_GAP + SLOTS_W + MARGIN

local CLASS_RANK = {}
for i, class in ipairs(D.CLASS_ORDER) do CLASS_RANK[class] = i end

local host = ns.overviewHost
local frame = host.child
ns.overview = frame
frame.rows = {}
-- The line between the columns, as between the class lists
frame.divider = frame:CreateTexture(nil, "ARTWORK")
frame.divider:SetColorTexture(1, 0.82, 0, 0.4)

-- The member's name without Forever's second name, his role marked after it - "(T)", "(H)";
-- a demo member brings his name, having no unit
local function Name(d)
    local name = d.name or (UnitName(d.unit))
    if d.role == "TANK" then return name .. " " .. L.OV_TANK end
    if d.role == "HEALER" then return name .. " " .. L.OV_HEALER end
    return name
end

-- An icon's tooltip: the game's, then who gave it - a demo member's giver by name - and the
-- minutes left
local function ShowIconTooltip(slot)
    GameTooltip:SetOwner(slot, "ANCHOR_TOP")
    GameTooltip:SetSpellByID(slot.spell)
    local c = slot.carried
    if c then
        local giver = c.by
        if not giver then
            local unit = c.source and B.InGroup(c.source)
            giver = unit and (UnitName(unit))
        end
        GameTooltip:AddLine(L.OV_FROM:format(giver or L.OV_ANOTHER), 1, 1, 1)
        if c.expires > 0 then
            GameTooltip:AddLine(L.OV_LEFT:format(math.ceil((c.expires - GetTime()) / 60)), 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function NewIcon(row)
    local slot = CreateFrame("Frame", nil, row)
    slot:SetSize(ICON, ICON)
    slot.tex = slot:CreateTexture(nil, "ARTWORK")
    slot.tex:SetAllPoints()
    slot.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    slot:EnableMouse(true)
    slot:SetScript("OnEnter", ShowIconTooltip)
    slot:SetScript("OnLeave", ns.HideTooltip)
    return slot
end

local function NewRow(i)
    local row = CreateFrame("Frame", nil, frame)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.aura = NewIcon(row) -- without border (Michel)
    row.slots = {}
    for s, family in ipairs(SLOTS) do
        local slot = NewIcon(row)
        slot.family = family
        slot.border = slot:CreateTexture(nil, "BACKGROUND")
        slot.border:SetPoint("TOPLEFT", -2, 2)
        slot.border:SetPoint("BOTTOMRIGHT", 2, -2)
        slot.border:SetColorTexture(1, 0.82, 0, 1)
        slot.plus = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        slot.plus:SetPoint("BOTTOMRIGHT", 2, -2)
        row.slots[s] = slot
    end
    frame.rows[i] = row
    return row
end

-- Places a row's parts for a column `colW` wide: the name takes what the rest leaves
local function LayRow(row, colW)
    row:SetSize(colW, ROW_H)
    local nameW = colW - FIXED_W
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", MARGIN, 0)
    row.name:SetWidth(nameW)
    local x = MARGIN + nameW + NAME_GAP
    row.aura:ClearAllPoints()
    row.aura:SetPoint("LEFT", x, 0)
    x = x + ICON + AURA_GAP
    for s, slot in ipairs(row.slots) do
        slot:ClearAllPoints()
        slot:SetPoint("LEFT", x + (s - 1) * (ICON + ICON_GAP), 0)
    end
end

-- Writes a member into a row: his name in his class colour, the aura he runs, then per slot
-- what he carries, or the faint next one in its family's place
local function FillRow(row, d)
    row.unit, row.role, row.class, row.greyed = d.unit, d.role, d.class, d.greyed
    row.name:SetText(Name(d))
    row.name:SetTextColor(C_ClassColor.GetClassColor(d.class):GetRGB())
    row.name:SetAlpha(d.greyed and 0.4 or 1)
    local aura = row.aura
    aura.carried = d.aura
    if d.aura then
        aura.spell = d.aura.spell
        aura.tex:SetTexture(C_Spell.GetSpellTexture(aura.spell))
        aura.tex:SetAlpha(d.greyed and 0.4 or 1)
        aura:Show()
    else
        aura:Hide()
    end
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

-- Members sorted by class in D.CLASS_ORDER, in group order within a class; the first half,
-- rounded up, in the left column, the rest in the right, both from the top
local function Build()
    local members = B.Overview()
    for i, d in ipairs(members) do d.index = i end
    table.sort(members, function(a, b)
        if a.class ~= b.class then return CLASS_RANK[a.class] < CLASS_RANK[b.class] end
        return a.index < b.index
    end)

    local colW = math.floor(host.scroll:GetWidth() / 2)
    local left = math.ceil(#members / 2)
    for i, d in ipairs(members) do
        local row = frame.rows[i] or NewRow(i)
        local column, line = 0, i - 1
        if i > left then column, line = 1, i - left - 1 end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", column * colW, -line * ROW_H)
        LayRow(row, colW)
        FillRow(row, d)
    end
    for i = #members + 1, #frame.rows do frame.rows[i]:Hide() end

    frame.divider:ClearAllPoints()
    frame.divider:SetPoint("TOPLEFT", colW, 0)
    frame.divider:SetSize(1, left * ROW_H)
    frame:SetSize(2 * colW, left * ROW_H)
end

-- Built when the tab shows, on every refresh while it does, on a language switch - its class
-- names are set here, not through ns.SetL - and when the window's width changes. The scroll
-- frame's own stretcher, registered before this one, has set its width by then; before the
-- window's first layout it has none, and the layout builds it.
local function BuildIfShown()
    if host.page:IsShown() and (host.scroll:GetWidth() or 0) > 0 then Build() end
end
host.page:HookScript("OnShow", BuildIfShown)
table.insert(ns.onRefresh, BuildIfShown)
ns.OnLanguageChanged(BuildIfShown)
table.insert(ns.UI.stretchers, BuildIfShown)
