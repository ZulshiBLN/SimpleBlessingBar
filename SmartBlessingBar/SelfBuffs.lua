-- SmartBlessingBar - aura and Righteous Fury buttons
-- The first two places on the bar. The aura button casts the highest known rank of the aura
-- its list picks: the first one no other paladin runs (ruleset plan 2026-10-19-priorities).
-- Both buttons show the marching ants while what they cast is missing - known out of combat
-- only, so they freeze in combat like the counts.

local _, ns = ...
if not ns.enabled then return end

local D, B = ns.D, ns.Blessings
local SetAttr = ns.SetAttr

local db
ns.OnDBReady(function(d) db = d end)

-- Placed by the bar's layout (Bar.lua), which puts these two first
local function NewButton(name, colorKey, speedKey)
    local b = ns.CreateSecureButton(name, ns.bar)
    b:SetScript("OnEnter", ns.ShowSpellTooltip)
    b:SetScript("OnLeave", ns.HideTooltip)
    ns.AttachAnts(b, colorKey, speedKey)
    return b
end

-- Left click only. No secure action in demo mode.
local function SetSpell(b, spell)
    SetAttr(b, "type1", (spell and not ns.IsDemo()) and "spell" or nil)
    SetAttr(b, "spell1", spell)
    SetAttr(b, "unit1", spell and "player" or nil)
    b.icon:SetDesaturated(not spell)
end

local aura = NewButton("SmartBlessingBarAura", "auraAntsColor", "auraAntsSpeed")
local fury = NewButton("SmartBlessingBarFury", "furyAntsColor", "furyAntsSpeed")
ns.auraButton, ns.furyButton = aura, fury
fury.icon:SetTexture(C_Spell.GetSpellTexture(D.RIGHTEOUS_FURY))

-- Whether the paladin's own aura of this family is on him; another paladin's does not count
-- Read in demo mode too: the glow follows the real aura there
local function OwnAuraUp(family)
    for _, a in ipairs(B.Auras("player", true)) do
        if a.mine and B.AURA_FAMILY[a.id] == family then return true end
    end
    return false
end

local function Update()
    -- None known: the first family on the list, rank 1, greyed and without ants. Hidden, the
    -- button chooses nothing and leaves nothing a /click could cast.
    local family = db.showAura and B.ChooseAura() or nil
    local spell = family and B.Best(D.AURAS[family])
    aura.shownSpell = spell or D.AURAS[db.auraList[1]][1]
    SetSpell(aura, spell)
    aura.icon:SetTexture(C_Spell.GetSpellTexture(aura.shownSpell))
    ns.SetAnts(aura, family ~= nil and not OwnAuraUp(family))

    -- Righteous Fury matters to a tank only: the role the game reports - a group's role
    -- check sets it; alone the game reports none (Michel, 2026-10-19). Demo mode reads no role.
    local known = B.Known(D.RIGHTEOUS_FURY)
    local tank = not ns.IsDemo() and UnitGroupRolesAssigned("player") == "TANK"
    SetSpell(fury, known and D.RIGHTEOUS_FURY or nil)
    fury.icon:SetDesaturated(not (known and tank))
    ns.SetAnts(fury, known and tank and not C_UnitAuras.GetPlayerAuraBySpellID(D.RIGHTEOUS_FURY))
end
table.insert(ns.onRefresh, Update)
