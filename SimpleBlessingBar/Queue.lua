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
    return ns.LocalName(C_Spell.GetSpellName(D.SALVATION), "SALVATION")
end

-- Whom the head reaches: the class for a Greater Blessing or Mass Salvation, which reach all
-- of it, else the member (ruleset plan 2026-10-20-button-tips-glow)
local function Target(head)
    if head.greater then
        local class = select(2, UnitClass(head.unit))
        return ns.LocalName(LOCALIZED_CLASS_NAMES_MALE[class], "CLASS_" .. class)
    end
    return (UnitName(head.unit))
end

-- The queue's head as the game's tooltip, with what a left click reaches; an empty queue says
-- so. The blessing button names its right click too.
local function ShowTooltip(b)
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    local head = b.head
    if head then
        GameTooltip:SetSpellByID(head.spell)
        GameTooltip:AddDoubleLine(L.LEFTCLICK, Target(head), 1, 1, 1)
    else
        GameTooltip:SetText(b.title())
        -- Entries left but none to cast: every one held at combat start
        GameTooltip:AddLine(b.left > 0 and L.QUEUE_HELD or L.QUEUE_EMPTY, 1, 1, 1)
    end
    if b.rightClickText then GameTooltip:AddDoubleLine(L.RIGHTCLICK, b.rightClickText(), 1, 1, 1) end
    GameTooltip:Show()
end

local function NewQueueButton(name, colorKey, speedKey, idleSpell, title)
    local b = ns.CreateSecureButton(name, ns.bar)
    b.idleSpell, b.title = idleSpell, title
    ns.AttachAnts(b, colorKey, speedKey)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", ns.HideTooltip)
    table.insert(ns.queueButtons, b)
    return b
end

local blessing = NewQueueButton("SimpleBlessingBarBlessing", "blessingAntsColor",
    "blessingAntsSpeed", D.BLESSINGS.KINGS.normal[1], function() return L.BTN_BLESSINGS end)
local salvation = NewQueueButton("SimpleBlessingBarSalvation", "salvationAntsColor",
    "salvationAntsSpeed", D.SALVATION, SalvationName)
ns.blessingButton, ns.salvationButton = blessing, salvation

-- A right click on the blessing button opens the lists that steer it, on its release; it
-- casts nothing, as no type2 is set. Not in combat, as the minimap button's middle click.
blessing.rightClickText = function() return L.SET_PRIORITIES end
blessing:HookScript("OnClick", function(_, mouseButton, down)
    if mouseButton ~= "RightButton" or down then return end
    if InCombatLockdown() then ns.Print(L.NOT_IN_COMBAT) return end
    ns.OpenSettingsOn("TAB_PRIORITIES")
end)

-- The blessing button shows the Symbols of Kings in its centre
blessing.symbols = blessing:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
blessing.symbols:SetPoint("CENTER", 0, 0)

-- The head: the first entry, but at combat start never one held back (planner `hold`)
local function Head(queue, combatStart)
    for _, entry in ipairs(queue) do
        if not (combatStart and entry.hold) then return entry end
    end
end

-- Writes a queue to its button, out of combat (the refresh runs only there). Left click
-- only; in demo mode no secure action, the click prints instead (Demo.lua).
local function Show(b, queue, combatStart)
    local head = Head(queue, combatStart)
    b.head, b.left = head, #queue
    SetAttr(b, "type1", (head and not ns.IsDemo()) and "spell" or nil)
    SetAttr(b, "spell1", head and head.spell)
    SetAttr(b, "unit1", head and head.unit)
    b.icon:SetTexture(C_Spell.GetSpellTexture(head and head.spell or b.idleSpell))
    b.icon:SetDesaturated(not head)
    b.count:SetText(#queue > 0 and tostring(#queue) or "")
    -- No ants while nothing can be cast, also with held entries left (ruleset plan
    -- 2026-10-19-blessing-steering)
    ns.SetAnts(b, head ~= nil)
end

table.insert(ns.onRefresh, function(combatStart)
    local queue, symbolsUsed = B.PlanBlessings()
    Show(blessing, queue, combatStart)
    ns.UpdateSymbols(blessing, B.AnyGreaterKnown())
    Show(salvation, B.PlanSalvation(symbolsUsed), combatStart)
end)
