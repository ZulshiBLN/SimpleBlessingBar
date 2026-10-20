-- SmartBlessingBar - the blessing and Salvation buttons
-- Each casts the head of its queue, which the planner (Blessings.lua) builds out of combat
-- from what the group carries (ruleset plan 2026-10-19-blessing-core). In combat the head
-- stays as the last refresh before it wrote it: aura data is unreadable then, and the secure
-- code cannot tell a cast that landed from one that failed.

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings
local SetAttr = ns.SetAttr
local db
ns.OnDBReady(function(d) db = d end)

local function SalvationName()
    return ns.LocalName(C_Spell.GetSpellName(D.SALVATION), "SALVATION")
end

-- Whom the head reaches: the class for a Greater Blessing or Mass Salvation, which reach all
-- of it, else the member (ruleset plan 2026-10-20-button-tips-glow). The planner names the
-- class: in combat the member may have left the group.
local function Target(head)
    if head.greater then
        return ns.LocalName(LOCALIZED_CLASS_NAMES_MALE[head.class], "CLASS_" .. head.class)
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
    local middle = b.middleClickText and b.middleClickText()
    if middle then GameTooltip:AddDoubleLine(L.MIDDLECLICK, middle, 1, 1, 1) end
    if b.rightClickText then GameTooltip:AddDoubleLine(L.RIGHTCLICK, b.rightClickText(), 1, 1, 1) end
    GameTooltip:Show()
end

local function NewQueueButton(name, colorKey, speedKey, idleSpell, title)
    local b = ns.CreateSecureButton(name, ns.bar)
    -- Nothing left until the first refresh, which waits for the end of combat after a /reload
    b.idleSpell, b.title, b.left = idleSpell, title, 0
    ns.AttachAnts(b, colorKey, speedKey)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", ns.HideTooltip)
    table.insert(ns.queueButtons, b)
    return b
end

local blessing = NewQueueButton("SmartBlessingBarBlessing", "blessingAntsColor",
    "blessingAntsSpeed", D.BLESSINGS.KINGS.normal[1], function() return L.BTN_BLESSINGS end)
local salvation = NewQueueButton("SmartBlessingBarSalvation", "salvationAntsColor",
    "salvationAntsSpeed", D.SALVATION, SalvationName)
ns.blessingButton, ns.salvationButton = blessing, salvation

-- Buff & Run (ruleset plan 2026-10-20-buff-and-run): the blessing button's middle click casts
-- on the current target what B.BuffRunSpell chose for him, then targets the next friendly
-- player - one macro, as the client lets an addon pick neither spell nor target during a
-- click. The cast goes through a hidden button holding the spell's ID, so the rank fits in
-- every language; "LeftButton 1" clicks it on key down, which works with
-- ActionButtonUseKeyDown on and off.
local buffRun = CreateFrame("Button", "SmartBlessingBarBuffRun", UIParent, "SecureActionButtonTemplate")
buffRun:RegisterForClicks("AnyUp", "AnyDown")
local BUFF_RUN_MACRO = "/click SmartBlessingBarBuffRun LeftButton 1\n/targetfriendplayer"

-- The middle click's attributes as every refresh leaves them, also at combat start: the
-- macro while the switch is on (General tab), and no spell, so in combat a middle click only
-- moves on. The hidden button's action is written here too, not at load: after a /reload in
-- combat the files load in the lockdown, where SetAttr writes nothing.
local function ArmBuffRun()
    local on = db.buffRun
    SetAttr(blessing, "type3", on and "macro" or nil)
    SetAttr(blessing, "macrotext3", on and BUFF_RUN_MACRO or nil)
    SetAttr(buffRun, "type", "spell")
    SetAttr(buffRun, "unit", "target")
    SetAttr(buffRun, "spell", nil)
end

-- Just before a middle click, out of combat: the spell for the current target. During the
-- global cooldown the click does nothing at all, so no player is passed by. Demo mode casts
-- nothing and says once, on the press, what it would cast.
blessing:SetScript("PreClick", function(_, mouseButton, down)
    if mouseButton ~= "MiddleButton" or InCombatLockdown() or not db.buffRun then return end
    local spell = B.WithRead(function() return B.BuffRunSpell("target") end)
    if spell and C_Spell.GetSpellCooldown(spell).startTime > 0 then
        SetAttr(blessing, "type3", nil)
        return
    end
    SetAttr(blessing, "type3", "macro")
    if ns.IsDemo() then
        if spell and down then ns.DemoCast(spell) end
        spell = nil
    end
    SetAttr(buffRun, "spell", spell)
end)

-- A right click on the blessing button opens the lists that steer it, on its release; it
-- casts nothing, as no type2 is set. Not in combat, as the minimap button's middle click.
blessing.rightClickText = function() return L.SET_PRIORITIES end
blessing.middleClickText = function() return db.buffRun and L.BUFF_RUN end
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

-- The Symbol count on the blessing button, shown once a Greater form is known
function ns.RefreshSymbols()
    ns.UpdateSymbols(blessing, B.AnyGreaterKnown())
end

-- A hidden button plans nothing: its empty queue also leaves nothing a /click could cast
table.insert(ns.onRefresh, function(combatStart)
    local queue, symbolsUsed = {}, 0
    if db.showBlessing then queue, symbolsUsed = B.PlanBlessings() end
    Show(blessing, queue, combatStart)
    ArmBuffRun()
    ns.RefreshSymbols()
    Show(salvation, db.showSalvation and B.PlanSalvation(symbolsUsed) or {}, combatStart)
end)
