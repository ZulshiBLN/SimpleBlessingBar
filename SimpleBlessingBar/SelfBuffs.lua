-- SimpleBlessingBar - aura and Righteous Fury buttons
-- The first two places on the bar. The aura button casts the chosen aura's highest known
-- rank; its flyout (Flyout.lua) chooses another. Both buttons show the marching ants while
-- what they cast is missing - known out of combat only, so they freeze in combat like the
-- counts.

local _, ns = ...
if not ns.enabled then return end

local D, B = ns.D, ns.Blessings
local SetAttr = ns.SetAttr

local db
ns.OnDBReady(function(d) db = d end)

-- Every aura ID of every family, to recognise any of the paladin's own auras
local AURA_IDS = {}
for _, list in pairs(D.AURAS) do
    for _, id in ipairs(list) do AURA_IDS[id] = true end
end

-- Placed by the bar's layout (Bar.lua), which puts these two first
local function NewButton(name, colorKey, speedKey)
    local b = ns.CreateSecureButton(name, ns.bar)
    b:SetScript("OnEnter", ns.ShowSpellTooltip)
    b:SetScript("OnLeave", ns.HideTooltip)
    ns.AttachAnts(b, colorKey, speedKey)
    return b
end

-- Left click only: right click stays free for the flyout. No secure action in demo mode.
local function SetSpell(b, spell)
    SetAttr(b, "type1", (spell and not ns.IsDemo()) and "spell" or nil)
    SetAttr(b, "spell1", spell)
    SetAttr(b, "unit1", spell and "player" or nil)
    b.icon:SetDesaturated(not spell)
end

local aura = NewButton("SimpleBlessingBarAura", "auraAntsColor", "auraAntsSpeed")
local fury = NewButton("SimpleBlessingBarFury", "furyAntsColor", "furyAntsSpeed")
ns.auraButton, ns.furyButton = aura, fury
fury.icon:SetTexture(C_Spell.GetSpellTexture(D.RIGHTEOUS_FURY))

-- The aura families the paladin knows, in flyout order
function ns.KnownAuras()
    local list = {}
    for _, key in ipairs(D.AURA_ORDER) do
        if B.Rank(D.AURAS[key]) then list[#list + 1] = key end
    end
    return list
end

-- Whether one of the paladin's own auras is on him; another paladin's does not count
local function OwnAuraUp()
    local i = 1
    while true do
        local data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL|PLAYER")
        if not data then return false end
        if AURA_IDS[data.spellId] then return true end
        i = i + 1
    end
end

local function Update()
    local list = D.AURAS[db.aura]
    local spell = B.Rank(list)
    SetSpell(aura, spell)
    aura.icon:SetTexture(C_Spell.GetSpellTexture(spell or list[1]))
    ns.SetAnts(aura, #ns.KnownAuras() > 0 and not OwnAuraUp())

    -- Righteous Fury matters to a tank only: the role the game reports - a group's role
    -- check sets it - never one set by hand; alone the game reports none (Michel, 2026-10-19)
    local known = B.Known(D.RIGHTEOUS_FURY)
    local tank = UnitGroupRolesAssigned("player") == "TANK"
    SetSpell(fury, known and D.RIGHTEOUS_FURY or nil)
    fury.icon:SetDesaturated(not (known and tank))
    ns.SetAnts(fury, known and tank and not C_UnitAuras.GetPlayerAuraBySpellID(D.RIGHTEOUS_FURY))
end
table.insert(ns.onRefresh, Update)
