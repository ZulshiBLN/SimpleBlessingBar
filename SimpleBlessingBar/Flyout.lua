-- SimpleBlessingBar - flyouts
-- Right click on a main button opens a row of icons above it; clicking an icon casts that
-- spell at once and makes it the main button's spell. Opening, closing and the copy to the
-- main button run as secure snippets on ns.header, so they work in combat. The icons' own
-- attributes are written out of combat by the refresh (ruleset plan 2026-10-18-flyouts).

local _, ns = ...
if not ns.enabled then return end

local D, B = ns.D, ns.Blessings
local SetAttr = ns.SetAttr
local SIZE, GAP = ns.BUTTON_SIZE, ns.BUTTON_GAP

local db
ns.OnDBReady(function(d) db = d end)

local header = CreateFrame("Frame", "SimpleBlessingBarHeader", UIParent, "SecureHandlerBaseTemplate")
ns.header = header

-- Every flyout key, as a Lua list for the snippets: built from constants only (code.md)
local KEYS = { "AURA" }
for _, class in ipairs(D.CLASS_ORDER) do KEYS[#KEYS + 1] = class end
local KEY_LIST = '"' .. table.concat(KEYS, '", "') .. '"'

-- Main button: right click opens its flyout and closes the others, on the up click; it
-- never casts. Left click passes through to the main button's own action.
local OPEN = ([[
    if button ~= "RightButton" then return end
    if not down then
        local fly = owner:GetFrameRef("fly_KEY")
        for _, k in ipairs(newtable(KEYS)) do
            local other = owner:GetFrameRef("fly_" .. k)
            if other and other ~= fly then other:Hide() end
        end
        if fly:IsShown() then fly:Hide() else fly:Show() end
    end
    return false
]]):gsub("KEYS", KEY_LIST)

-- Icon: left click on an icon with an action casts it; the message lets the post body run.
local CHOOSE_PRE = [[
    if button ~= "LeftButton" or not self:GetAttribute("type1") then return false end
    return nil, "chosen"
]]

-- After the cast: the main button takes the icon's action; the flyout closes on the up click.
local CHOOSE_POST = [[
    local main = owner:GetFrameRef("main_KEY")
    main:SetAttribute("type1", self:GetAttribute("type1"))
    main:SetAttribute("spell1", self:GetAttribute("spell1"))
    main:SetAttribute("unit1", self:GetAttribute("unit1"))
    if not down then self:GetParent():Hide() end
]]

local flyouts = {}
ns.flyouts = flyouts

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetSpellByID(self:GetAttribute("spell1"))
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

-- The insecure half of a choice: remember it. Only on the click that casts - key down while
-- ActionButtonUseKeyDown is on, else key up - so a press dragged off the icon still counts.
local function Save(icon, mouseButton, down)
    if mouseButton ~= "LeftButton" or not icon:GetAttribute("type1") then return end
    if (down == true) ~= (GetCVarBool("ActionButtonUseKeyDown") == true) then return end
    icon:GetParent().save(icon.family, icon:GetAttribute("spell1"))
end

-- One flyout above a main button. `save(family, spell)` stores a choice and shows it on the
-- main button; the counts follow at the next refresh.
function ns.CreateFlyout(key, main, save)
    local fly = CreateFrame("Frame", "SimpleBlessingBarFlyout" .. key, main)
    fly:SetPoint("BOTTOM", main, "TOP", 0, GAP)
    fly:SetSize(SIZE, SIZE)
    fly:Hide()
    fly.key, fly.main, fly.save, fly.icons = key, main, save, {}
    header:SetFrameRef("fly_" .. key, fly)
    header:SetFrameRef("main_" .. key, main)
    header:WrapScript(main, "OnClick", (OPEN:gsub("KEY", key)))
    flyouts[key] = fly
    return fly
end

-- The flyout's i-th icon, created on demand. The wrap comes before the hook: wrapping
-- replaces the click script, and a hook set earlier would be lost.
local function Icon(fly, i)
    local icon = fly.icons[i]
    if icon then return icon end
    icon = CreateFrame("Button", fly:GetName() .. "Icon" .. i, fly, "SecureActionButtonTemplate")
    icon:SetSize(SIZE, SIZE)
    icon:SetPoint("BOTTOM", fly, "BOTTOM", 0, (i - 1) * (SIZE + GAP))
    icon:RegisterForClicks("AnyUp", "AnyDown")
    icon.icon = icon:CreateTexture(nil, "ARTWORK")
    icon.icon:SetAllPoints()
    header:WrapScript(icon, "OnClick", CHOOSE_PRE, (CHOOSE_POST:gsub("KEY", fly.key)))
    icon:HookScript("OnClick", Save)
    icon:SetScript("OnEnter", ShowTooltip)
    icon:SetScript("OnLeave", HideTooltip)
    fly.icons[i] = icon
    return icon
end

-- Writes a flyout's icons, out of combat (the refresh runs only there). entries: list of
-- { family, spell, unit }; unit nil = nobody to cast on, the icon is greyed and inert.
function ns.FillFlyout(fly, entries)
    for i, entry in ipairs(entries) do
        local icon = Icon(fly, i)
        icon.family = entry.family
        local castable = entry.unit ~= nil
        SetAttr(icon, "type1", castable and "spell" or nil)
        SetAttr(icon, "spell1", entry.spell)
        SetAttr(icon, "unit1", entry.unit)
        icon.icon:SetTexture(C_Spell.GetSpellTexture(entry.spell))
        icon.icon:SetDesaturated(not castable)
        icon:Show()
    end
    for i = #entries + 1, #fly.icons do fly.icons[i]:Hide() end
    fly:SetHeight(math.max(1, #entries) * (SIZE + GAP) - GAP)
end

---------------------------------------------------------------------------
-- Aura flyout
---------------------------------------------------------------------------
local auraFly = ns.CreateFlyout("AURA", ns.auraButton, function(family, spell)
    db.aura = family
    ns.auraButton.icon:SetTexture(C_Spell.GetSpellTexture(spell))
    ns.auraButton.icon:SetDesaturated(false)
end)

table.insert(ns.onRefresh, function()
    local entries = {}
    for _, key in ipairs(ns.KnownAuras()) do
        entries[#entries + 1] = { family = key, spell = B.Rank(D.AURAS[key]), unit = "player" }
    end
    ns.FillFlyout(auraFly, entries)
end)

---------------------------------------------------------------------------
-- Class flyouts
---------------------------------------------------------------------------
-- Each icon carries its own target: the member lacking that very blessing, chosen out of
-- combat - so a Salvation icon stays within the paladin's party.
local classFlys = {}
for _, class in ipairs(D.CLASS_ORDER) do
    local button = ns.classButtons[class]
    classFlys[class] = ns.CreateFlyout(class, button, function(family, spell)
        db.assign[class] = family
        button.blessIcon:SetTexture(C_Spell.GetSpellTexture(spell))
        button.blessIcon:SetDesaturated(false)
        button.classIcon:SetDesaturated(false)
    end)
end

-- Only the classes in the group: each icon scans the group once a second
table.insert(ns.onRefresh, function()
    for _, class in ipairs(D.CLASS_ORDER) do
        if ns.classButtons[class]:IsShown() then
            local entries = {}
            for _, family in ipairs(B.KnownFamilies()) do
                local state = B.ClassState(class, family)
                entries[#entries + 1] = { family = family, spell = state.spell, unit = state.target }
            end
            ns.FillFlyout(classFlys[class], entries)
        end
    end
end)
