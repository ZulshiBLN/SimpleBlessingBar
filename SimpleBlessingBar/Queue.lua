-- SimpleBlessingBar - the blessing and Salvation buttons
-- Each casts the head of its queue, which the planner (Blessings.lua) builds out of combat
-- from what the group carries (ruleset plan 2026-10-19-blessing-core). In combat the head
-- stays as the last refresh before it wrote it: aura data is unreadable then, and the secure
-- code cannot tell a cast that landed from one that failed.

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings
local SetAttr = ns.SetAttr

local function SalvationName()
    return ns.LocalName(C_Spell.GetSpellName(D.SALVATION), "BLESSING_SALVATION")
end

-- The queue's head as the game's tooltip, with its target; an empty queue says so
local function ShowTooltip(b)
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    local head = b.head
    if head then
        GameTooltip:SetSpellByID(head.spell)
        GameTooltip:AddLine(UnitName(head.unit), 1, 1, 1)
    else
        GameTooltip:SetText(b.title())
        GameTooltip:AddLine(L.QUEUE_EMPTY, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function NewQueueButton(name, showKey, colorKey, speedKey, idleSpell, title)
    local b = ns.CreateSecureButton(name, ns.bar)
    b.showKey, b.idleSpell, b.title = showKey, idleSpell, title
    ns.AttachAnts(b, colorKey, speedKey)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", ns.HideTooltip)
    table.insert(ns.queueButtons, b)
    return b
end

local blessing = NewQueueButton("SimpleBlessingBarBlessing", "showBlessing", "blessingAntsColor",
    "blessingAntsSpeed", D.BLESSINGS.KINGS.normal[1], function() return L.BTN_BLESSINGS end)
local salvation = NewQueueButton("SimpleBlessingBarSalvation", "showSalvation", "salvationAntsColor",
    "salvationAntsSpeed", D.SALVATION, SalvationName)
ns.blessingButton, ns.salvationButton = blessing, salvation

-- The blessing button shows the Symbols of Kings in its centre, as the class buttons do
blessing.symbols = blessing:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
blessing.symbols:SetPoint("CENTER", 0, 0)

-- The head: the first entry, but at combat start never one held back (planner `hold`)
local function Head(queue, combatStart)
    for _, entry in ipairs(queue) do
        if not (combatStart and entry.hold) then return entry end
    end
end

-- Writes a queue to its button, out of combat (the refresh runs only there). Left click
-- only; in demo mode no secure action, the click prints instead (Flyout.lua).
local function Show(b, queue, combatStart)
    local head = Head(queue, combatStart)
    b.head = head
    SetAttr(b, "type1", (head and not ns.IsDemo()) and "spell" or nil)
    SetAttr(b, "spell1", head and head.spell)
    SetAttr(b, "unit1", head and head.unit)
    b.icon:SetTexture(C_Spell.GetSpellTexture(head and head.spell or b.idleSpell))
    b.icon:SetDesaturated(not head)
    b.count:SetText(#queue > 0 and tostring(#queue) or "")
    ns.SetAnts(b, #queue > 0)
end

table.insert(ns.onRefresh, function(combatStart)
    local queue, symbolsUsed = B.PlanBlessings()
    Show(blessing, queue, combatStart)
    ns.UpdateSymbols(blessing, B.AnyGreaterKnown())
    Show(salvation, B.PlanSalvation(symbolsUsed), combatStart)
end)
