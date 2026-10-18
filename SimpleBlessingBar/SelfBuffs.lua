-- SimpleBlessingBar - aura and Righteous Fury buttons
-- The first two places on the bar. The aura button casts the chosen aura's highest known
-- rank; its flyout (Flyout.lua) chooses another. Both buttons glow while what they cast is
-- missing - known out of combat only, so the glow freezes in combat like the counts.

local _, ns = ...
if not ns.enabled then return end

local D, B = ns.D, ns.Blessings
local SetAttr = ns.SetAttr
local SIZE, GAP = ns.BUTTON_SIZE, ns.BUTTON_GAP

local db
ns.OnDBReady(function(d) db = d end)

-- Every aura ID of every family, to recognise any of the paladin's own auras
local AURA_IDS = {}
for _, list in pairs(D.AURAS) do
    for _, id in ipairs(list) do AURA_IDS[id] = true end
end

local function NewButton(name, x)
    local b = CreateFrame("Button", name, ns.bar, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:SetPoint("LEFT", ns.bar, "LEFT", x, 0)
    -- A secure click acts on key down or up per ActionButtonUseKeyDown; both are registered
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetAllPoints()
    b.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()
    return b
end

-- Left click only: right click stays free for the flyout
local function SetSpell(b, spell)
    SetAttr(b, "type1", spell and "spell" or nil)
    SetAttr(b, "spell1", spell)
    SetAttr(b, "unit1", spell and "player" or nil)
    b.icon:SetDesaturated(not spell)
end

local aura = NewButton("SimpleBlessingBarAura", 0)
local fury = NewButton("SimpleBlessingBarFury", SIZE + GAP)
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

local function SetGlow(b, on)
    if on then b.glow:Show() else b.glow:Hide() end
end

local function Update()
    local list = D.AURAS[db.aura]
    local spell = B.Rank(list)
    SetSpell(aura, spell)
    aura.icon:SetTexture(C_Spell.GetSpellTexture(spell or list[1]))
    SetGlow(aura, #ns.KnownAuras() > 0 and not OwnAuraUp())

    local known = IsPlayerSpell(D.RIGHTEOUS_FURY)
    SetSpell(fury, known and D.RIGHTEOUS_FURY or nil)
    SetGlow(fury, known and not C_UnitAuras.GetPlayerAuraBySpellID(D.RIGHTEOUS_FURY))
end
table.insert(ns.onRefresh, Update)
