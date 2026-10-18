-- SimpleBlessingBar - aura and Righteous Fury buttons
-- The first two places on the bar. The aura button casts the chosen aura's highest known
-- rank; its flyout (Flyout.lua) chooses another. Both buttons glow while what they cast is
-- missing - known out of combat only, so the glow freezes in combat like the counts.

local _, ns = ...
if not ns.enabled then return end

local D, B = ns.D, ns.Blessings
local SetAttr = ns.SetAttr
local SIZE = D.SIZE

local db
ns.OnDBReady(function(d) db = d end)

-- Every aura ID of every family, to recognise any of the paladin's own auras
local AURA_IDS = {}
for _, list in pairs(D.AURAS) do
    for _, id in ipairs(list) do AURA_IDS[id] = true end
end

-- The highlight ("marching ants" like spell procs in the Retail client), as in
-- SimpleConjureBar. It sits on its own frame above the button; the animation runs
-- (OnUpdate) only while the highlight is visible. Color and speed are the button's own
-- settings: colorKey and speedKey name them.
local function AttachAnts(b, colorKey, speedKey)
    local holder = CreateFrame("Frame", nil, b)
    holder:SetAllPoints()
    holder:SetFrameLevel(b:GetFrameLevel() + 2)

    local ants = holder:CreateTexture(nil, "OVERLAY")
    ants:SetTexture(D.ANTS_TEX)
    ants:SetDesaturated(true)
    ants:SetBlendMode("ADD")
    ants:SetPoint("CENTER")
    ants:SetSize(SIZE * 1.42, SIZE * 1.42)
    ants:Hide()

    local frame, timer = 0, 0
    local function SetFrame(i)
        local col, row = i % D.ANTS_COLS, math.floor(i / D.ANTS_COLS)
        ants:SetTexCoord(col * D.ANTS_CELL, (col + 1) * D.ANTS_CELL, row * D.ANTS_CELL, (row + 1) * D.ANTS_CELL)
    end
    SetFrame(0)

    b.ants, b.antsHolder, b.antsColorKey = ants, holder, colorKey
    b.antsUpdate = function(_, elapsed)
        local step = D.ANTS_STEPS[db[speedKey]]
        timer = timer + elapsed
        if timer < step then return end
        frame = (frame + math.floor(timer / step)) % D.ANTS_FRAMES
        timer = timer % step
        SetFrame(frame)
    end
end

-- Placed by the bar's layout (Bar.lua), which puts these two first
local function NewButton(name, colorKey, speedKey)
    local b = ns.CreateSecureButton(name, ns.bar)
    b:SetScript("OnEnter", ns.ShowSpellTooltip)
    b:SetScript("OnLeave", ns.HideTooltip)
    AttachAnts(b, colorKey, speedKey)
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

-- The ants' colors are part of the look (ns.ApplyLook), so the color picker reaches them
table.insert(ns.onLook, function()
    for _, b in ipairs({ aura, fury }) do
        local c = db[b.antsColorKey]
        b.ants:SetVertexColor(c.r, c.g, c.b, c.a)
    end
end)

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

    local known = B.Known(D.RIGHTEOUS_FURY)
    SetSpell(fury, known and D.RIGHTEOUS_FURY or nil)
    SetAnts(fury, known and not C_UnitAuras.GetPlayerAuraBySpellID(D.RIGHTEOUS_FURY))
end
table.insert(ns.onRefresh, Update)
