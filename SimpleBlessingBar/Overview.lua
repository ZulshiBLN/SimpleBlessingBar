-- SimpleBlessingBar - the overview, at the foot of the Priorities tab
-- Members by class, the blessings and Salvation they carry, mine bordered, the one this
-- paladin would give next faint (ruleset plans 2026-10-19-overview, 2026-10-19-priorities).
-- Built out of combat from the planner's reads, when the tab is shown and on every refresh
-- while it is. Loaded after SettingsPages.lua, which makes the scroll frame it fills.

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings

local ROW_H, HEADER_H, ICON, ICON_GAP, NAME_W = 20, 18, 16, 3, 150
local SLOTS = { "MIGHT", "WISDOM", "KINGS", "LIGHT", "SALVATION" } -- D.BLESSING_ORDER, Salvation last
local COL_W = NAME_W + #SLOTS * (ICON + ICON_GAP) + 10
local FOOTER_H = 16

local host = ns.overviewHost
local frame = host.child
ns.overview = frame
frame.rows, frame.headers, frame.footer = {}, {}, {}

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

local function ClassName(class)
    return ns.LocalName(LOCALIZED_CLASS_NAMES_MALE[class], "CLASS_" .. class)
end

-- The member's name without Forever's second name, his role from the game marked after it -
-- "(T)", "(H)"; a class name without marks in demo mode
local function Name(d)
    if ns.IsDemo() then return ClassName(d.class) end
    local name = (UnitName(d.unit))
    if d.role == "TANK" then return name .. " " .. L.OV_TANK end
    if d.role == "HEALER" then return name .. " " .. L.OV_HEALER end
    return name
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
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetWidth(NAME_W - 4)
    row.name:SetJustifyH("LEFT")
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
    row.unit, row.role, row.class, row.greyed = d.unit, d.role, d.class, d.greyed
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

-- Sections by class in D.CLASS_ORDER, one column; the footer below the rows, inside the
-- scroll frame
local function Build()
    local members = B.Overview()
    local byClass = {}
    for _, d in ipairs(members) do
        byClass[d.class] = byClass[d.class] or {}
        table.insert(byClass[d.class], d)
    end

    local nRows, nHeaders, y = 0, 0, 0
    for _, class in ipairs(D.CLASS_ORDER) do
        local list = byClass[class]
        if list then
            nHeaders = nHeaders + 1
            local h = frame.headers[nHeaders] or NewHeader(nHeaders)
            h.class = class
            h:SetText(ClassName(class))
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -y)
            h:Show()
            y = y + HEADER_H
            for _, d in ipairs(list) do
                nRows = nRows + 1
                local row = frame.rows[nRows] or NewRow(nRows)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                FillRow(row, d)
                y = y + ROW_H
            end
        end
    end
    for i = nRows + 1, #frame.rows do frame.rows[i]:Hide() end
    for i = nHeaders + 1, #frame.headers do frame.headers[i]:Hide() end

    -- The footer: per paladin in the group, then Others if any; none in demo mode
    local texts = {}
    if not ns.IsDemo() then
        local lines, others = B.Footer(members)
        for _, l in ipairs(lines) do texts[#texts + 1] = FooterText((UnitName(l.unit)), l.counts) end
        if next(others) then texts[#texts + 1] = FooterText(L.OV_OTHERS, others) end
    end
    y = y + (#texts > 0 and 8 or 0)
    for i, text in ipairs(texts) do
        local f = frame.footer[i]
        if not f then
            f = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f:SetJustifyH("LEFT")
            frame.footer[i] = f
        end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 0, -y)
        f:SetText(text)
        f:Show()
        y = y + FOOTER_H
    end
    for i = #texts + 1, #frame.footer do frame.footer[i]:Hide() end
    -- As wide as a row, or the longest footer line: a raid's paladin can give five things
    local width = COL_W
    for i = 1, #texts do width = math.max(width, frame.footer[i]:GetStringWidth()) end
    frame:SetSize(width, y)
end

-- Built when the tab shows, on every refresh while it does, and on a language switch: its
-- class names and footer texts are set here, not through ns.SetL
local function BuildIfShown()
    if host.page:IsShown() then Build() end
end
host.page:HookScript("OnShow", Build)
table.insert(ns.onRefresh, BuildIfShown)
ns.OnLanguageChanged(BuildIfShown)
