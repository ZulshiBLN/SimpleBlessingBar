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

---------------------------------------------------------------------------
-- The planner (ruleset plan 2026-10-19-blessing-core, IMPLEMENTATION "Definitions")
-- Out of combat it decides, from what the group carries, what this paladin casts next.
---------------------------------------------------------------------------
-- Blessings are the families of the role lists; Salvation never counts as one
local IS_BLESSING = {}
for _, list in pairs(D.ROLE_LISTS) do
    for _, family in ipairs(list) do IS_BLESSING[family] = true end
end

-- This paladin's blessing on a unit: its family and whether it is the Greater form, or nil
local function MyBlessingOn(unit)
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")
        if not aura then return end
        local rank = RANKS[aura.spellId]
        if rank and IS_BLESSING[rank.family] then return rank.family, rank.greater end
        i = i + 1
    end
end

-- The best known Greater rank of a family: its ID and strength, or nil
local function BestGreater(family)
    local best, strength
    for i, id in ipairs(D.BLESSINGS[family].greater) do
        if B.Known(id) then best, strength = id, D.GREATER_EQUALS[family][i] end
    end
    return best, strength
end

local function Symbols()
    return ns.IsDemo() and D.DEMO_SYMBOLS or C_Item.GetItemCount(D.SYMBOL_OF_KINGS)
end

-- The first family of the unit's role list this paladin knows and others have not given
function B.ChosenFamily(unit)
    for _, family in ipairs(D.ROLE_LISTS[B.RoleOf(unit)]) do
        local f = D.BLESSINGS[family]
        if (B.Rank(f.normal) or B.Rank(f.greater)) and not B.GivenByOthers(unit, family) then
            return family
        end
    end
end

-- Done for this paladin: a normal blessing of mine, or my Greater one of the chosen family.
-- My Greater one of another family is replaced by the exception.
local function Done(chosen, mine, mineGreater)
    if not mine then return false end
    return not mineGreater or mine == chosen
end

-- The Greater family of a class: the one chosen for most of its members, ties by
-- D.BLESSING_ORDER
local ORDER_INDEX = {}
for i, family in ipairs(D.BLESSING_ORDER) do ORDER_INDEX[family] = i end
local function GreaterFamily(members)
    local count = {}
    for _, m in ipairs(members) do
        if m.chosen then count[m.chosen] = (count[m.chosen] or 0) + 1 end
    end
    local best
    for family, n in pairs(count) do
        if not best or n > count[best] or (n == count[best] and ORDER_INDEX[family] < ORDER_INDEX[best]) then
            best = family
        end
    end
    return best
end

-- The blessing queue: entries { spell, unit, greater, hold }, Greater entries first, then
-- normal ones in group order. `hold`: a Greater entry for a class with exceptions, which must
-- not come first at combat start - the exceptions after it could not follow in combat. Also
-- returns the Symbols its Greater entries use. Out of combat only.
function B.PlanBlessings()
    local byClass, order = {}, {}
    for _, unit in ipairs(B.Members()) do
        local class = select(2, UnitClass(unit))
        if class and B.Eligible(unit) then
            local mine, mineGreater = MyBlessingOn(unit)
            local m = { unit = unit, chosen = B.ChosenFamily(unit), mine = mine }
            m.done = Done(m.chosen, mine, mineGreater)
            byClass[class] = byClass[class] or {}
            table.insert(byClass[class], m)
            order[#order + 1] = m
        end
    end

    local symbols = Symbols()
    local queue, covered = {}, {}
    for _, class in ipairs(D.CLASS_ORDER) do
        local members = byClass[class]
        local family = members and GreaterFamily(members)
        local spell, greaterStrength
        if family then spell, greaterStrength = BestGreater(family) end
        if spell then
            -- Only members in range count, so a cast that misses the others is not repeated
            local lacking, target, exceptions = 0, nil, false
            for _, m in ipairs(members) do
                if m.chosen and m.chosen ~= family then exceptions = true end
                if B.InRange(spell, m.unit) then
                    target = target or m.unit
                    if m.chosen == family and m.mine ~= family then lacking = lacking + 1 end
                end
            end
            -- The stronger form wins; between equals the group decides (Michel, 2026-10-19)
            local normalStrength = B.BestKnownNormal(family)
            local useGreater = greaterStrength > normalStrength
                or (greaterStrength == normalStrength and IsInRaid() and lacking >= D.RAID_GREATER_MIN)
            if useGreater and (lacking == 0 or symbols > 0) then
                if lacking > 0 then
                    symbols = symbols - 1
                    queue[#queue + 1] = { spell = spell, unit = target, greater = true, hold = exceptions }
                end
                for _, m in ipairs(members) do
                    if m.chosen == family then covered[m] = true end
                end
            end
        end
    end

    for _, m in ipairs(order) do
        if m.chosen and not m.done and not covered[m] then
            local spell = B.Rank(D.BLESSINGS[m.chosen].normal)
            if spell and B.InRange(spell, m.unit) then
                queue[#queue + 1] = { spell = spell, unit = m.unit }
            end
        end
    end
    return queue, Symbols() - symbols
end

-- Whether a unit carries Salvation or Mass Salvation, from anyone
local function HasSalvation(unit)
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then return false end
        if aura.spellId == D.SALVATION or aura.spellId == D.MASS_SALVATION then return true end
        i = i + 1
    end
end

-- The Salvation queue: Salvation for every member whose role is not tank, Revoke for a tank
-- carrying it from anyone. In a raid a class gets Mass Salvation when its non-tanks in range
-- who lack it reach the threshold plus its tanks, each of whom needs a Revoke after it. Mass
-- Salvation first, then Revoke, then single Salvation in group order. `symbolsUsed` are the
-- Symbols the blessing queue already plans. Out of combat only.
function B.PlanSalvation(symbolsUsed)
    if not B.Known(D.SALVATION) then return {} end
    local byClass, classes, position = {}, {}, {}
    for i, unit in ipairs(B.Members()) do
        position[unit] = i
        local class = select(2, UnitClass(unit))
        if class and B.Eligible(unit) and B.InRange(D.SALVATION, unit) then
            local m = { unit = unit, tank = B.RoleOf(unit) == "TANK", has = HasSalvation(unit) }
            if not byClass[class] then
                byClass[class] = {}
                classes[#classes + 1] = class
            end
            table.insert(byClass[class], m)
        end
    end

    local symbols = Symbols() - (symbolsUsed or 0)
    local mass, revoke, single = {}, {}, {}
    for _, class in ipairs(classes) do
        local lacking, tanks = {}, 0
        for _, m in ipairs(byClass[class]) do
            if m.tank then
                tanks = tanks + 1
                if m.has and B.Known(D.REVOKE) then revoke[#revoke + 1] = { spell = D.REVOKE, unit = m.unit } end
            elseif not m.has then
                lacking[#lacking + 1] = m
            end
        end
        if IsInRaid() and B.Known(D.MASS_SALVATION) and symbols > 0 and #lacking >= D.RAID_GREATER_MIN + tanks then
            symbols = symbols - 1
            -- `hold`: with tanks in the class, its Revokes could not follow in combat
            mass[#mass + 1] = { spell = D.MASS_SALVATION, unit = lacking[1].unit, greater = true, hold = tanks > 0 }
        else
            for _, m in ipairs(lacking) do single[#single + 1] = { spell = D.SALVATION, unit = m.unit } end
        end
    end
    table.sort(single, function(a, b) return position[a.unit] < position[b.unit] end)

    local queue = mass
    for _, e in ipairs(revoke) do queue[#queue + 1] = e end
    for _, e in ipairs(single) do queue[#queue + 1] = e end
    return queue
end
