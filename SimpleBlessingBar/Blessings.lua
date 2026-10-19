-- SimpleBlessingBar - blessing logic
-- Which rank to cast, roles, what others gave, and the planner behind the blessing and
-- Salvation buttons (ruleset plan 2026-10-19-blessing-core).
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

-- Whether any Greater Blessing or Mass Salvation is known - only then is a Symbol of Kings
-- of use
function B.AnyGreaterKnown()
    for _, family in ipairs(D.BLESSING_ORDER) do
        if B.Rank(D.BLESSINGS[family].greater) then return true end
    end
    return B.Known(D.MASS_SALVATION)
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

function B.Eligible(unit)
    return UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit)
end

function B.InRange(spell, unit)
    return UnitIsUnit(unit, "player") or C_Spell.IsSpellInRange(spell, unit) == true
end

-- Whether the game lets a spell land on a unit's level. A level the game does not give sets
-- no limit; demo mode sets none either.
function B.Fits(spell, unit)
    if ns.IsDemo() then return true end
    local learned, level = C_Spell.GetSpellLevelLearned(spell), UnitLevel(unit)
    if not learned or learned <= 0 or not level or level <= 0 then return true end
    return level >= learned - D.LEVEL_GAP
end

-- The highest known entry of a list ordered by rank that fits the unit, or nil
function B.RankFor(list, unit)
    local best
    for _, id in ipairs(list) do
        if B.Known(id) and B.Fits(id, unit) then best = id end
    end
    return best
end

---------------------------------------------------------------------------
-- Roles and presence (ruleset plan 2026-10-19-blessing-core)
---------------------------------------------------------------------------
-- The game's group roles, mapped onto ours
local DAMAGE_ROLES = { MELEE = true, RANGED = true, CASTER = true }

-- A member's role: the one the game reports where the class can play it - a damage dealer
-- gets the class's first damage role - else the class default.
function B.RoleOf(unit, class)
    local roles = D.CLASS_ROLES[class or select(2, UnitClass(unit))]
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
    if ns.IsDemo() then return mine end
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")
        if not aura then return mine end
        mine[aura.auraInstanceID] = true
        i = i + 1
    end
end

-- The index of the best normal rank of a family this paladin knows that fits the unit, 0 for
-- none
local function BestFittingNormal(family, unit)
    local best = 0
    for i, id in ipairs(D.BLESSINGS[family].normal) do
        if B.Known(id) and B.Fits(id, unit) then best = i end
    end
    return best
end

-- Whether another paladin gave the unit this family: in its Greater form, or a normal rank
-- at least the best one of this paladin's that fits the unit. A lower rank counts as missing
-- - casting it again is worth it (Michel, 2026-10-19). Read out of combat only.
function B.GivenByOthers(unit, family)
    if ns.IsDemo() then return false end -- demo mode reads no auras
    local mine = MineOn(unit)
    local best = BestFittingNormal(family, unit)
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
    if ns.IsDemo() then return end
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

-- The first family of the unit's role list this paladin can give the unit - a normal rank or
-- the best known Greater one fits - and others have not given
function B.ChosenFamily(unit, class)
    for _, family in ipairs(D.ROLE_LISTS[B.RoleOf(unit, class)]) do
        local f = D.BLESSINGS[family]
        local greater = B.Rank(f.greater)
        if (B.RankFor(f.normal, unit) or (greater and B.Fits(greater, unit)))
           and not B.GivenByOthers(unit, family) then
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

-- The members the planner works on: { unit, class }. Demo mode shows every class, with its
-- default role and no auras, every entry on the player.
local function Roster()
    local list = {}
    if ns.IsDemo() then
        for _, class in ipairs(D.CLASS_ORDER) do list[#list + 1] = { unit = "player", class = class } end
        return list
    end
    for _, unit in ipairs(B.Members()) do
        local class = select(2, UnitClass(unit))
        if class and B.Eligible(unit) then list[#list + 1] = { unit = unit, class = class } end
    end
    return list
end

-- The blessing queue: entries { spell, unit, greater, hold }, Greater entries first, then
-- normal ones in group order. `hold`: a Greater entry for a class with exceptions, which must
-- not come first at combat start - the exceptions after it could not follow in combat. Also
-- returns the Symbols its Greater entries use. Out of combat only.
function B.PlanBlessings()
    local byClass, order = {}, {}
    for _, r in ipairs(Roster()) do
        local mine, mineGreater = MyBlessingOn(r.unit)
        local m = { unit = r.unit, chosen = B.ChosenFamily(r.unit, r.class), mine = mine }
        m.done = Done(m.chosen, mine, mineGreater)
        byClass[r.class] = byClass[r.class] or {}
        table.insert(byClass[r.class], m)
        order[#order + 1] = m
    end

    local symbols = Symbols()
    local queue, covered = {}, {}
    for _, class in ipairs(D.CLASS_ORDER) do
        local members = byClass[class]
        local family = members and GreaterFamily(members)
        local spell, greaterStrength
        if family then spell, greaterStrength = BestGreater(family) end
        if spell then
            -- Only members in range count, so a cast that misses the others is not repeated.
            -- Members it does not fit count for nothing: they get a normal one that fits.
            local lacking, target, exceptions = 0, nil, false
            for _, m in ipairs(members) do
                m.fitsGreater = B.Fits(spell, m.unit)
                if m.fitsGreater then
                    if m.chosen and m.chosen ~= family then exceptions = true end
                    if B.InRange(spell, m.unit) then
                        target = target or m.unit
                        if m.chosen == family and m.mine ~= family then lacking = lacking + 1 end
                    end
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
                    if m.chosen == family and m.fitsGreater then covered[m] = true end
                end
            end
        end
    end

    for _, m in ipairs(order) do
        if m.chosen and not m.done and not covered[m] then
            local spell = B.RankFor(D.BLESSINGS[m.chosen].normal, m.unit)
            if spell and B.InRange(spell, m.unit) then
                queue[#queue + 1] = { spell = spell, unit = m.unit }
            end
        end
    end
    return queue, Symbols() - symbols
end

-- Whether a unit carries Salvation or Mass Salvation, from anyone
local function HasSalvation(unit)
    if ns.IsDemo() then return false end
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
    for i, r in ipairs(Roster()) do
        position[r] = i
        if B.InRange(D.SALVATION, r.unit) then
            local m = { unit = r.unit, tank = B.RoleOf(r.unit, r.class) == "TANK", has = HasSalvation(r.unit), at = r }
            if not byClass[r.class] then
                byClass[r.class] = {}
                classes[#classes + 1] = r.class
            end
            table.insert(byClass[r.class], m)
        end
    end

    local symbols = Symbols() - (symbolsUsed or 0)
    local mass, revoke, single = {}, {}, {}
    for _, class in ipairs(classes) do
        -- Mass Salvation counts only the members it fits; the others get single Salvation
        local lacking, massLacking, massTanks = {}, {}, 0
        for _, m in ipairs(byClass[class]) do
            m.fitsMass = B.Fits(D.MASS_SALVATION, m.unit)
            if m.tank then
                if m.fitsMass then massTanks = massTanks + 1 end
                if m.has and B.Known(D.REVOKE) and B.Fits(D.REVOKE, m.unit) then
                    revoke[#revoke + 1] = { spell = D.REVOKE, unit = m.unit }
                end
            elseif not m.has then
                lacking[#lacking + 1] = m
                if m.fitsMass then massLacking[#massLacking + 1] = m end
            end
        end
        local useMass = IsInRaid() and B.Known(D.MASS_SALVATION) and symbols > 0
            and #massLacking >= D.RAID_GREATER_MIN + massTanks
        if useMass then
            symbols = symbols - 1
            -- `hold`: with tanks it reaches, their Revokes could not follow in combat
            mass[#mass + 1] = { spell = D.MASS_SALVATION, unit = massLacking[1].unit, greater = true, hold = massTanks > 0 }
        end
        for _, m in ipairs(lacking) do
            if not (useMass and m.fitsMass) and B.Fits(D.SALVATION, m.unit) then
                single[#single + 1] = { spell = D.SALVATION, unit = m.unit, at = m.at }
            end
        end
    end
    table.sort(single, function(a, b) return position[a.at] < position[b.at] end)

    local queue = mass
    for _, e in ipairs(revoke) do queue[#queue + 1] = e end
    for _, e in ipairs(single) do queue[#queue + 1] = e end
    return queue
end
