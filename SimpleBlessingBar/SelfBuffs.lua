-- SimpleBlessingBar - aura and Righteous Fury buttons
-- The first two places on the bar. The aura button casts the chosen aura's highest known
-- rank; right click chooses another. The Righteous Fury button is highlighted while it is
-- missing - known out of combat only, so the highlight freezes in combat like the counts.

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings
local SetAttr = ns.SetAttr
local SIZE, GAP = ns.BUTTON_SIZE, ns.BUTTON_GAP

local db
ns.OnDBReady(function(d) db = d end)

local AURA_KEYS = {
    DEVOTION = "AURA_DEVOTION", RETRIBUTION = "AURA_RETRIBUTION", CONCENTRATION = "AURA_CONCENTRATION",
    SHADOW = "AURA_SHADOW", FROST = "AURA_FROST", FIRE = "AURA_FIRE", SANCTITY = "AURA_SANCTITY",
}

local function NewButton(name, x)
    local b = CreateFrame("Button", name, ns.bar, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:SetPoint("LEFT", ns.bar, "LEFT", x, 0)
    -- A secure click acts on key down or up per ActionButtonUseKeyDown; both are registered
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    return b
end

-- Left click only: right click stays free for the menu
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
fury.glow = fury:CreateTexture(nil, "OVERLAY")
fury.glow:SetAllPoints()
fury.glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
fury.glow:SetBlendMode("ADD")
fury.glow:Hide()

local function Update()
    local list = D.AURAS[db.aura]
    local spell = B.Rank(list)
    SetSpell(aura, spell)
    aura.icon:SetTexture(C_Spell.GetSpellTexture(spell or list[1]))

    local known = IsPlayerSpell(D.RIGHTEOUS_FURY)
    SetSpell(fury, known and D.RIGHTEOUS_FURY or nil)
    local missing = known and not C_UnitAuras.GetPlayerAuraBySpellID(D.RIGHTEOUS_FURY)
    if missing then fury.glow:Show() else fury.glow:Hide() end
end
table.insert(ns.onRefresh, Update)

-- The aura families the paladin knows, in menu order
function ns.KnownAuras()
    local list = {}
    for _, key in ipairs(D.AURA_ORDER) do
        if B.Rank(D.AURAS[key]) then list[#list + 1] = key end
    end
    return list
end

function ns.AuraName(key)
    local list = D.AURAS[key]
    return ns.LocalName(C_Spell.GetSpellName(B.Rank(list) or list[1]), AURA_KEYS[key])
end

function ns.ChooseAura(key)
    if not D.AURAS[key] then return end
    db.aura = key
    ns.Refresh()
end

function ns.OpenAuraMenu()
    MenuUtil.CreateContextMenu(aura, function(_, root)
        root:CreateTitle(L.MENU_AURA)
        for _, key in ipairs(ns.KnownAuras()) do
            root:CreateRadio(ns.AuraName(key),
                function() return db.aura == key end,
                function() ns.ChooseAura(key) end)
        end
    end)
end

-- Both key down and up reach OnClick; the menu opens once, on the up click.
aura:HookScript("OnClick", function(_, mouseButton, down)
    if mouseButton == "RightButton" and not down then ns.OpenAuraMenu() end
end)
