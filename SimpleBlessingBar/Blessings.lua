-- SimpleBlessingBar - blessing logic
-- Which rank to cast, who in the group lacks a blessing, and whom a class button targets.
-- Runs out of combat only: aura data returns nothing in combat (ruleset research
-- 2026-10-18-paladin-facts, section 3), so the callers freeze its results there.

local _, ns = ...
if not ns.enabled then return end

local D = ns.D

local B = {}
ns.Blessings = B

-- The one test of a known spell; in demo mode every spell counts as known
function B.Known(id)
    return ns.IsDemo() or IsPlayerSpell(id)
end

-- The highest known entry of a list ordered by rank, or nil
function B.Rank(list)
    local best
    for _, id in ipairs(list) do
        if B.Known(id) then best = id end
    end
    return best
end

-- The spell a class button casts for a blessing family: the Greater form when known and a
-- Symbol of Kings is in the bags (in demo mode: assumed), otherwise the highest known normal
-- rank. Returns the spell ID and whether it is a Greater Blessing, or nil when nothing is known.
function B.CastSpell(familyKey)
    local family = D.BLESSINGS[familyKey]
    if not family then return end
    local greater = B.Rank(family.greater)
    if greater and (ns.IsDemo() or C_Item.GetItemCount(D.SYMBOL_OF_KINGS) > 0) then return greater, true end
    local normal = B.Rank(family.normal)
    if normal then return normal, false end
end

-- Whether any Greater Blessing is known - only then is a Symbol of Kings of use
function B.AnyGreaterKnown()
    for _, family in ipairs(D.BLESSING_ORDER) do
        if B.Rank(D.BLESSINGS[family].greater) then return true end
    end
    return false
end

-- The blessing families the paladin knows in any rank or form, in flyout order
function B.KnownFamilies()
    local list = {}
    for _, family in ipairs(D.BLESSING_ORDER) do
        local f = D.BLESSINGS[family]
        if B.Rank(f.normal) or B.Rank(f.greater) then list[#list + 1] = family end
    end
    return list
end

-- The group's unit tokens: alone the player, in a party the player and party1-4, in a raid
-- raid1-40. Pets are not members.
function B.Members()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        if IsInGroup() then
            for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
        end
    end
    return units
end

-- The units in the paladin's own party: everyone outside a raid, the own subgroup in one
function B.PartySet()
    local set = {}
    if not IsInRaid() then
        for _, unit in ipairs(B.Members()) do set[unit] = true end
        return set
    end
    local mine
    for i = 1, GetNumGroupMembers() do
        if UnitIsUnit("raid" .. i, "player") then mine = select(3, GetRaidRosterInfo(i)) end
    end
    for i = 1, GetNumGroupMembers() do
        if select(3, GetRaidRosterInfo(i)) == mine then set["raid" .. i] = true end
    end
    return set
end

function B.Eligible(unit)
    return UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit)
end

function B.InRange(spell, unit)
    return UnitIsUnit(unit, "player") or C_Spell.IsSpellInRange(spell, unit) == true
end

---------------------------------------------------------------------------
-- Roles and presence (ruleset plan 2026-10-19-blessing-core)
---------------------------------------------------------------------------
-- The game's group roles, mapped onto ours
local DAMAGE_ROLES = { MELEE = true, RANGED = true, CASTER = true }

-- A member's role: the one the game reports where the class can play it - a damage dealer
-- gets the class's first damage role - else the class default.
function B.RoleOf(unit)
    local roles = D.CLASS_ROLES[select(2, UnitClass(unit))]
    if not roles then return end
    local reported = UnitGroupRolesAssigned(unit)
    for _, role in ipairs(roles) do
        if role == reported or (reported == "DAMAGER" and DAMAGE_ROLES[role]) then return role end
    end
    return roles[1]
end

-- Spell ID -> { family, strength, greater }: a normal rank's strength is its index in the
-- normal list, a Greater rank's the normal index it equals (D.GREATER_EQUALS)
local RANKS = {}
for family, f in pairs(D.BLESSINGS) do
    for i, id in ipairs(f.normal) do RANKS[id] = { family = family, strength = i } end
    for i, id in ipairs(f.greater) do
        local equals = D.GREATER_EQUALS[family]
        RANKS[id] = { family = family, strength = equals and equals[i], greater = true }
    end
end
B.RANKS = RANKS

-- The index of the best normal rank of a family this paladin knows, 0 for none
function B.BestKnownNormal(family)
    local best = 0
    for i, id in ipairs(D.BLESSINGS[family].normal) do
        if B.Known(id) then best = i end
    end
    return best
end

-- The aura instances on a unit this paladin cast ("HELPFUL|PLAYER")
local function MineOn(unit)
    local mine, i = {}, 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")
        if not aura then return mine end
        mine[aura.auraInstanceID] = true
        i = i + 1
    end
end

-- Whether another paladin gave the unit this family: in its Greater form, or a normal rank
-- at least this paladin's best known one. A lower rank counts as missing - casting it again
-- is worth it (Michel, 2026-10-19). Read out of combat only.
function B.GivenByOthers(unit, family)
    local mine = MineOn(unit)
    local best = B.BestKnownNormal(family)
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then return false end
        local rank = RANKS[aura.spellId]
        if rank and rank.family == family and not mine[aura.auraInstanceID]
           and (rank.greater or rank.strength >= best) then
            return true
        end
        i = i + 1
    end
end

-- This paladin's aura of the family on the unit, normal or Greater, any rank; another
-- paladin's blessing is not returned ("HELPFUL|PLAYER").
function B.AuraOf(unit, familyKey)
    local family = D.BLESSINGS[familyKey]
    local ids = {}
    for _, id in ipairs(family.normal) do ids[id] = true end
    for _, id in ipairs(family.greater) do ids[id] = true end
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")
        if not aura then return end
        if ids[aura.spellId] then return aura end
        i = i + 1
    end
end

-- The state of one class button: { castable, spell, greater, count, target }.
-- count: eligible members of the class lacking the blessing. target: the first lacking
-- member in range; else the member in range whose blessing ends first; else nil.
-- In demo mode: the sample count of D.DEMO_COUNTS and the player as target, without reading
-- auras or units.
function B.ClassState(class, familyKey)
    local spell, greater = B.CastSpell(familyKey)
    if not spell then return { castable = false, count = 0 } end
    if ns.IsDemo() then
        return { castable = true, spell = spell, greater = greater, count = D.DEMO_COUNTS[class], target = "player" }
    end

    local party = (D.BLESSINGS[familyKey].normalPartyOnly and not greater) and B.PartySet() or nil
    local state = { castable = true, spell = spell, greater = greater, count = 0 }
    local soonest, soonestUnit
    for _, unit in ipairs(B.Members()) do
        if select(2, UnitClass(unit)) == class and B.Eligible(unit) and (not party or party[unit]) then
            local aura = B.AuraOf(unit, familyKey)
            local inRange = B.InRange(spell, unit)
            if not aura then
                state.count = state.count + 1
                if inRange and not state.target then state.target = unit end
            elseif inRange and (not soonest or aura.expirationTime < soonest) then
                soonest, soonestUnit = aura.expirationTime, unit
            end
        end
    end
    state.target = state.target or soonestUnit
    return state
end
