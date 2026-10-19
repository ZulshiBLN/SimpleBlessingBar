-- SimpleBlessingBar - flyouts
-- Right click on a main button opens a row of icons above it; clicking an icon selects that
-- spell for the main button, without casting it - the main button's left click casts.
-- Opening, closing, the auto-hide and the copy to the main button run as secure snippets on
-- ns.header, so they work in combat. The icons' attributes are written out of combat by the
-- refresh (ruleset plan 2026-10-18-flyouts).

local _, ns = ...
if not ns.enabled then return end

local D, B = ns.D, ns.Blessings
local SetAttr = ns.SetAttr
local SIZE, GAP, PAD = D.SIZE, D.GAP, D.PAD

local db
ns.OnDBReady(function(d) db = d end)

local header = CreateFrame("Frame", "SimpleBlessingBarHeader", UIParent, "SecureHandlerBaseTemplate")
ns.header = header

-- Every flyout key, as a Lua list for the snippets: built from constants only (code.md).
-- The aura flyout is the one left since the class buttons went (blessing core plan).
local KEYS = { "AURA" }
local KEY_LIST = '"' .. table.concat(KEYS, '", "') .. '"'

-- Closes every open flyout but `fly`. Pasted into the snippets below.
local CLOSE_ALL = [[
        for _, k in ipairs(newtable(KEYS)) do
            local other = owner:GetFrameRef("fly_" .. k)
            if other and other ~= fly and other:IsShown() then
                other:Hide()
                other:UnregisterAutoHide()
            end
        end
]]

-- Main button: right click opens its flyout and closes the others, on the up click; it
-- never casts. Shown, the flyout hides itself once the mouse has left it and its button for
-- the header's "autohide" seconds - the client's secure auto-hide, allowed in combat; 0 is
-- off, and no attribute yet (before the first refresh) is D.FLYOUT_AUTOHIDE. Any other
-- click - a left click that casts - closes every open flyout and lets the cast through
-- (Michel, 2026-10-18).
local OPEN = ([[
    local fly = owner:GetFrameRef("fly_KEY")
    if button ~= "RightButton" then
        fly = nil
CLOSE_ALL
        return
    end
    if not down then
CLOSE_ALL
        if fly:IsShown() then
            fly:Hide()
            fly:UnregisterAutoHide()
        else
            fly:Show()
            local seconds = owner:GetAttribute("autohide")
            if seconds == nil then seconds = AUTOHIDE end
            if seconds > 0 then
                fly:RegisterAutoHide(seconds)
                fly:AddToAutoHide(self)
            end
        end
    end
    return false
]]):gsub("CLOSE_ALL", CLOSE_ALL):gsub("KEYS", KEY_LIST):gsub("AUTOHIDE", tostring(D.FLYOUT_AUTOHIDE))

-- A main button without a flyout (Righteous Fury): its click closes every open flyout too
local CLOSE = ([[
    local fly = nil
CLOSE_ALL
]]):gsub("CLOSE_ALL", CLOSE_ALL):gsub("KEYS", KEY_LIST)

-- Icon: only a left click, on its release, on an icon with a spell, selects; the message
-- lets the post body run. An icon casts nothing itself - it has no secure action.
local CHOOSE_PRE = [[
    if down or button ~= "LeftButton" or not self:GetAttribute("sbbspell") then return false end
    return nil, "chosen"
]]

-- The main button takes the icon's spell and target; the flyout closes. In demo mode (the
-- header's "demo" attribute) it gets no secure action, so it still casts nothing.
local CHOOSE_POST = [[
    local main = owner:GetFrameRef("main_KEY")
    if not owner:GetAttribute("demo") then main:SetAttribute("type1", "spell") end
    main:SetAttribute("spell1", self:GetAttribute("sbbspell"))
    main:SetAttribute("unit1", self:GetAttribute("sbbunit"))
    local fly = self:GetParent()
    fly:Hide()
    fly:UnregisterAutoHide()
]]

local flyouts = {}
ns.flyouts = flyouts

-- The insecure half of a choice: remember it, on the same click the snippet accepts. A press
-- dragged off the icon brings no release there, and selects nothing.
local function Save(icon, mouseButton, down)
    if down or mouseButton ~= "LeftButton" or not icon:GetAttribute("sbbspell") then return end
    icon:GetParent().save(icon.family, icon:GetAttribute("sbbspell"))
end

-- Icons carry no spell1, so their tooltip reads the spell they offer
local function IconTooltip(icon)
    GameTooltip:SetOwner(icon, "ANCHOR_TOP")
    GameTooltip:SetSpellByID(icon.spell)
    GameTooltip:Show()
end

-- One flyout above a main button. `save(family, spell)` stores a choice and shows it on the
-- main button; the counts follow at the next refresh.
-- Looks as in SimpleConjureBar: the bar's background and border, and a small arrow above
-- the main button that marks it as having a flyout.
function ns.CreateFlyout(key, main, save)
    local arrow = main:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
    arrow:SetSize(14, 14)
    arrow:SetPoint("BOTTOM", main, "TOP", 0, -6)
    main.arrow = arrow

    -- Protected in its own right (SecureFrameTemplate), not only through its secure icons:
    -- the open snippet touches every flyout in combat, and a flyout without icons - no aura
    -- learned yet - would otherwise be an invalid handle there and stop the snippet.
    local fly = CreateFrame("Frame", "SimpleBlessingBarFlyout" .. key, main, "SecureFrameTemplate, BackdropTemplate")
    fly:SetPoint("BOTTOM", main, "TOP", 0, 6)
    fly:SetSize(SIZE + 2 * PAD, SIZE + 2 * PAD)
    ns.ApplyBackdrop(fly)
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
    icon = ns.CreateSecureButton(fly:GetName() .. "Icon" .. i, fly)
    header:WrapScript(icon, "OnClick", CHOOSE_PRE, (CHOOSE_POST:gsub("KEY", fly.key)))
    icon:HookScript("OnClick", Save)
    icon:SetScript("OnEnter", IconTooltip)
    icon:SetScript("OnLeave", ns.HideTooltip)
    fly.icons[i] = icon
    return icon
end

-- Writes a flyout's icons, out of combat (the refresh runs only there). entries: list of
-- { family, spell, unit }; unit nil = nobody to cast on, the icon is greyed and inert.
-- The flyout opens in the direction the bar computed (ns.flyDir), as in SimpleConjureBar.
function ns.FillFlyout(fly, entries)
    local lay = D.FLY_LAYOUT[ns.flyDir or "UP"]
    local main = fly.main
    fly:ClearAllPoints()
    fly:SetPoint(lay.fly[1], main, lay.fly[2], lay.fly[3], lay.fly[4])
    main.arrow:ClearAllPoints()
    main.arrow:SetPoint(lay.arrow[1], main, lay.arrow[2], lay.arrow[3], lay.arrow[4])
    main.arrow:SetRotation(lay.rot)
    for i, entry in ipairs(entries) do
        local icon = Icon(fly, i)
        local off = PAD + (i - 1) * (SIZE + GAP)
        icon:ClearAllPoints()
        icon:SetPoint(lay.child, fly, lay.child, lay.dx * off, lay.dy * off)
        icon.family, icon.spell = entry.family, entry.spell
        local castable = entry.unit ~= nil
        SetAttr(icon, "sbbspell", castable and entry.spell or nil)
        SetAttr(icon, "sbbunit", entry.unit)
        icon.icon:SetTexture(C_Spell.GetSpellTexture(entry.spell))
        icon.icon:SetDesaturated(not castable)
        icon:Show()
    end
    for i = #entries + 1, #fly.icons do fly.icons[i]:Hide() end
    local long = math.max(1, #entries) * (SIZE + GAP) - GAP + 2 * PAD
    if lay.dx ~= 0 then fly:SetSize(long, SIZE + 2 * PAD) else fly:SetSize(SIZE + 2 * PAD, long) end
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

-- Buttons without a flyout: their click closes every open flyout too
for _, b in ipairs({ ns.furyButton, ns.blessingButton, ns.salvationButton }) do
    header:WrapScript(b, "OnClick", CLOSE)
end

-- The auto-close time and demo mode reach the snippets as data, never in their text (code.md)
table.insert(ns.onRefresh, function()
    SetAttr(header, "autohide", db.flyoutAutoClose and db.flyoutAutoCloseTime or 0)
    SetAttr(header, "demo", ns.IsDemo() or nil)
end)

---------------------------------------------------------------------------
-- Demo mode: a left click on a main button says what it would cast
---------------------------------------------------------------------------
-- Spell ID -> its name key, and whether it is a Greater Blessing (the keys name the normal form)
local NAME_KEYS = {
    [D.RIGHTEOUS_FURY] = { key = "RIGHTEOUS_FURY" },
    [D.SALVATION] = { key = "SALVATION" },
    [D.MASS_SALVATION] = { key = "MASS_SALVATION" },
    [D.REVOKE] = { key = "REVOKE" },
}
for family, f in pairs(D.BLESSINGS) do
    for _, id in ipairs(f.normal) do NAME_KEYS[id] = { key = "BLESSING_" .. family } end
    for _, id in ipairs(f.greater) do NAME_KEYS[id] = { key = "BLESSING_" .. family, greater = true } end
end
for family, list in pairs(D.AURAS) do
    for _, id in ipairs(list) do NAME_KEYS[id] = { key = "AURA_" .. family } end
end

local function DemoClick(b, mouseButton, down)
    if down or mouseButton ~= "LeftButton" or not ns.IsDemo() then return end
    local spell = b:GetAttribute("spell1")
    if not spell then return end
    local n = NAME_KEYS[spell]
    local client = C_Spell.GetSpellName(spell)
    local name = ns.LocalName(client, n.key)
    if n.greater and name ~= client then name = ns.L.DEMO_GREATER:format(name) end
    ns.DemoPrint(ns.L.DEMO_CAST, name)
end

-- Set after every main button's wrap: wrapping replaces the click script, and a hook set
-- earlier would be lost.
for _, b in ipairs({ ns.auraButton, ns.furyButton, ns.blessingButton, ns.salvationButton }) do
    b:HookScript("OnClick", DemoClick)
end
