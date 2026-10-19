-- SimpleBlessingBar - demo mode's chat output
-- In demo mode the main buttons carry no secure action; a left click says what it would cast
-- (ruleset plan 2026-10-18-settings-window; moved from Flyout.lua by plan
-- 2026-10-19-priorities). Loaded after Queue.lua, once all four buttons exist.

local _, ns = ...
if not ns.enabled then return end

local D = ns.D

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

for _, b in ipairs({ ns.auraButton, ns.furyButton, ns.blessingButton, ns.salvationButton }) do
    b:HookScript("OnClick", DemoClick)
end
