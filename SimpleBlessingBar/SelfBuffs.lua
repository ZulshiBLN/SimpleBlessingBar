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

-- The highlight ("marching ants" like spell procs in the Retail client), as in
-- SimpleConjureBar. It sits on its own frame above the button; the animation runs
-- (OnUpdate) only while the highlight is visible.
local function AttachAnts(b)
    local holder = CreateFrame("Frame", nil, b)
    holder:SetAllPoints()
    holder:SetFrameLevel(b:GetFrameLevel() + 2)

    local ants = holder:CreateTexture(nil, "OVERLAY")
    ants:SetTexture(D.ANTS_TEX)
    ants:SetDesaturated(true)
    ants:SetBlendMode("ADD")
    ants:SetVertexColor(D.ANTS_COLOR.r, D.ANTS_COLOR.g, D.ANTS_COLOR.b, D.ANTS_COLOR.a)
    ants:SetPoint("CENTER")
    ants:SetSize(SIZE * 1.42, SIZE * 1.42)
    ants:Hide()

    local frame, timer = 0, 0
    local function SetFrame(i)
        local col, row = i % D.ANTS_COLS, math.floor(i / D.ANTS_COLS)
        ants:SetTexCoord(col * D.ANTS_CELL, (col + 1) * D.ANTS_CELL, row * D.ANTS_CELL, (row + 1) * D.ANTS_CELL)
    end
    SetFrame(0)

    b.ants, b.antsHolder = ants, holder
    b.antsUpdate = function(_, elapsed)
        timer = timer + elapsed
        if timer < D.ANTS_STEP then return end
        frame = (frame + math.floor(timer / D.ANTS_STEP)) % D.ANTS_FRAMES
        timer = timer % D.ANTS_STEP
        SetFrame(frame)
    end
end

local function NewButton(name, x)
    local b = CreateFrame("Button", name, ns.bar, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    b:SetPoint("LEFT", ns.bar, "LEFT", x, 0)
    -- A secure click acts on key down or up per ActionButtonUseKeyDown; both are registered
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    AttachAnts(b)
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

-- Shows or hides a button's highlight and starts or stops its animation
local function SetAnts(b, shown)
    if shown == b.antsShown then return end
    b.antsShown = shown
    if shown then
        b.ants:Show()
        b.antsHolder:SetScript("OnUpdate", b.antsUpdate)
    else
        b.ants:Hide()
        b.antsHolder:SetScript("OnUpdate", nil)
    end
end

local function Update()
    local list = D.AURAS[db.aura]
    local spell = B.Rank(list)
    SetSpell(aura, spell)
    aura.icon:SetTexture(C_Spell.GetSpellTexture(spell or list[1]))
    SetAnts(aura, #ns.KnownAuras() > 0 and not OwnAuraUp())

    local known = IsPlayerSpell(D.RIGHTEOUS_FURY)
    SetSpell(fury, known and D.RIGHTEOUS_FURY or nil)
    SetAnts(fury, known and not C_UnitAuras.GetPlayerAuraBySpellID(D.RIGHTEOUS_FURY))
end
table.insert(ns.onRefresh, Update)
