-- SmartBlessingBar - blessing logic
-- Which rank to cast, roles, what others gave, and the planner behind the blessing and
-- Salvation buttons (ruleset plan 2026-10-19-blessing-core).
-- Runs out of combat only: aura data returns nothing in combat (ruleset research
-- 2026-10-18-paladin-facts, section 3), so the callers freeze its results there.

local _, ns = ...
if not ns.enabled then return end

local D = ns.D
local db
ns.OnDBReady(function(d) db = d end)

local B = {}
ns.Blessings = B

-- Whether the client lets the addon read auras now. Not in combat; and since Midnight, in
-- instances and PvP it keeps them secret out of combat too and refuses a read with an error
-- (BugSack, 2026-10-20). Where C_Secrets is missing, one read is tried.
function B.AurasReadable()
    if InCombatLockdown() then return false end
    local secret = C_Secrets and C_Secrets.ShouldAurasBeSecret
    if secret then return not secret() end
    return (pcall(C_UnitAuras.GetAuraDataByIndex, "player", 1, "HELPFUL"))
end

-- An aura's spell ID, or nil while the game keeps any field the addon reads secret: such a
-- buff counts as unread (code.md). Every reader asks this before using the others.
function B.SpellOf(aura)
    if issecretvalue(aura.spellId) or issecretvalue(aura.expirationTime)
       or issecretvalue(aura.auraInstanceID) or issecretvalue(aura.sourceUnit) then
        return
    end
    return aura.spellId
end

---------------------------------------------------------------------------
-- One read of the group (ruleset plan 2026-10-20-performance-pvp): between B.BeginRead and
-- B.EndRead - a refresh, a Buff & Run click, an overview build - each person's buffs are
-- scanned once and each spell's "known" and each member's level asked once. Outside a read
-- every call asks the client fresh.
---------------------------------------------------------------------------
local read -- { auras = key -> list, known = id -> bool, level = unit -> level } during a read

function B.BeginRead() read = { auras = {}, known = {}, level = {} } end
function B.EndRead() read = nil end

-- fn inside a read: the running one, or one of its own. A read an error left open is closed
-- by the next refresh's B.BeginRead.
function B.WithRead(fn)
    if read then return fn() end
    B.BeginRead()
    local result = fn()
    B.EndRead()
    return result
end

-- A person's key: his GUID, so `player`, `raidN` and `target` share one snapshot; a GUID the
-- client withholds or keeps secret falls back to the token
local function PersonKey(unit)
    local guid = UnitGUID(unit)
    if guid == nil or issecretvalue(guid) then return unit end
    return guid
end

-- A unit's readable buffs, { id, expires, mine, source } each, in the client's order
local function Scan(unit)
    local mineIds, list = {}, {}
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL|PLAYER")
        if not aura then break end
        if B.SpellOf(aura) then mineIds[aura.auraInstanceID] = true end
        i = i + 1
    end
    i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        local id = B.SpellOf(aura)
        if id then
            list[#list + 1] = { id = id, expires = aura.expirationTime,
                                mine = mineIds[aura.auraInstanceID] == true, source = aura.sourceUnit }
        end
        i = i + 1
    end
    return list
end

local NONE = {}

-- The buffs a unit carries. Demo mode reads none; `real` reads them there too - the aura
-- button's own aura - kept apart from demo mode's empty answer.
function B.Auras(unit, real)
    local demo = ns.IsDemo()
    if demo and not real then return NONE end
    if not read then return Scan(unit) end
    local key = PersonKey(unit)
    local list = read.auras[key]
    if not list then
        list = Scan(unit)
        read.auras[key] = list
    end
    return list
end

-- The one test of a known spell; in demo mode every spell counts as known
function B.Known(id)
    if ns.IsDemo() then return true end
    if not read then return IsPlayerSpell(id) end
    local known = read.known[id]
    if known == nil then
        known = IsPlayerSpell(id)
        read.known[id] = known
    end
    return known
end

-- Whether any Greater Blessing or Mass Salvation is known - only then is a Symbol of Kings
-- of use
function B.AnyGreaterKnown()
    for _, family in ipairs(D.BLESSING_ORDER) do
        if B.Best(D.BLESSINGS[family].greater) then return true end
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

-- The level a spell is learned at, a constant of the spell, kept for the session. Only a
-- positive answer is kept: nil means the client has not loaded it yet (code.md).
local learnedAt = {}
local function Learned(spell)
    local learned = learnedAt[spell]
    if not learned then
        learned = C_Spell.GetSpellLevelLearned(spell)
        if learned and learned > 0 then learnedAt[spell] = learned end
    end
    return learned
end

local function LevelOf(unit)
    if not read then return UnitLevel(unit) end
    local level = read.level[unit]
    if level == nil then
        level = UnitLevel(unit) or false
        read.level[unit] = level
    end
    return level or nil
end

-- Whether the game lets a spell land on a unit's level. A level the game does not give sets
-- no limit; demo mode sets none either.
function B.Fits(spell, unit)
    if ns.IsDemo() then return true end
    local learned, level = Learned(spell), LevelOf(unit)
    if not learned or learned <= 0 or not level or level <= 0 then return true end
    return level >= learned - D.LEVEL_GAP
end

-- The best known entry of a list ordered by rank - IDs do not rise with rank (Data.lua) - and
-- its index, or nil. With a unit only ranks that fit him count.
function B.Best(list, unit)
    local best, index
    for i, id in ipairs(list) do
        if B.Known(id) and (not unit or B.Fits(id, unit)) then best, index = id, i end
    end
    return best, index
end

---------------------------------------------------------------------------
-- Roles and presence (ruleset plan 2026-10-19-blessing-core)
---------------------------------------------------------------------------

-- A member's role: the one the game reports, where the class can play it - a damage dealer
-- gets the class's first damage role - else the class default. Nothing sets a role by hand
-- (Michel, 2026-10-19). Demo mode puts every class on the player, so it reads no role: each
-- class shows its default.
function B.RoleOf(unit, class)
    local roles = D.CLASS_ROLES[class or select(2, UnitClass(unit))]
    if not roles then return end
    if ns.IsDemo() then return roles[1] end
    local reported = UnitGroupRolesAssigned(unit)
    for _, role in ipairs(roles) do
        if role == reported or (reported == "DAMAGER" and D.DAMAGE_ROLES[role]) then return role end
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

-- Whether another paladin gave the unit this family: in its Greater form, or a normal rank
-- at least the best one of this paladin's that fits the unit. A lower rank counts as missing
-- - casting it again is worth it (Michel, 2026-10-19). Read out of combat only.
function B.GivenByOthers(unit, family)
    local best = select(2, B.Best(D.BLESSINGS[family].normal, unit)) or 0
    for _, a in ipairs(B.Auras(unit)) do
        local rank = RANKS[a.id]
        if rank and rank.family == family and not a.mine and (rank.greater or rank.strength >= best) then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- The planner (ruleset plan 2026-10-19-blessing-core, IMPLEMENTATION "Definitions")
-- Out of combat it decides, from what the group carries, what this paladin casts next.
---------------------------------------------------------------------------
-- Blessings are the families of D.BLESSING_ORDER; Salvation never counts as one
local IS_BLESSING = {}
for _, family in ipairs(D.BLESSING_ORDER) do IS_BLESSING[family] = true end

-- Whether an aura of mine runs out within the renewal time, so it is renewed before it is
-- gone (ruleset plan 2026-10-19-blessing-steering). An aura without expiry never is.
local function Expiring(a)
    return a.expires > 0 and a.expires - GetTime() < db.renewMinutes * 60
end

-- The family of this paladin's blessing on a unit, normal or Greater, or nil - also when it
-- is about to run out
local function MyBlessingOn(unit)
    for _, a in ipairs(B.Auras(unit)) do
        local rank = a.mine and RANKS[a.id]
        if rank and IS_BLESSING[rank.family] then
            if Expiring(a) then return end
            return rank.family
        end
    end
end

-- The best known Greater rank of a family: its ID and strength, or nil
local function BestGreater(family)
    local best, index = B.Best(D.BLESSINGS[family].greater)
    if best then return best, D.GREATER_EQUALS[family][index] end
end

-- The Symbols of Kings in the bags; demo mode's sample count
function B.Symbols()
    return ns.IsDemo() and D.DEMO_SYMBOLS or C_Item.GetItemCount(D.SYMBOL_OF_KINGS)
end
local Symbols = B.Symbols

-- The first family of the unit's class list, as the player edited it, this paladin can give
-- the unit - a normal rank or the best known Greater one fits - and others have not given
-- (ruleset plan 2026-10-19-priorities: lists by class, roles no longer choose)
function B.ChosenFamily(unit, class)
    for _, family in ipairs(db.classLists[class or select(2, UnitClass(unit))].order) do
        local f = D.BLESSINGS[family]
        local greater = B.Best(f.greater)
        if (B.Best(f.normal, unit) or (greater and B.Fits(greater, unit)))
           and not B.GivenByOthers(unit, family) then
            return family
        end
    end
end

-- Done for this paladin: my blessing on the member, normal or Greater, is of the chosen
-- family. One of another family is replaced, so a change of list is cast at once
-- (Michel, 2026-10-19).
local function Done(chosen, mine)
    return mine ~= nil and mine == chosen
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
        -- A class without a list in Data.lua is left out: UnitClass is outside data
        local class = select(2, UnitClass(unit))
        if D.CLASS_LISTS[class or ""] and B.Eligible(unit) then list[#list + 1] = { unit = unit, class = class } end
    end
    return list
end

-- The blessing queue: entries { spell, unit, greater, hold, class }, Greater entries first, then
-- normal ones in group order. `hold`: a Greater entry for a class with exceptions, which must
-- not come first at combat start - the exceptions after it could not follow in combat. Also
-- returns the Symbols its Greater entries use. Out of combat only.
function B.PlanBlessings()
    local byClass, order = {}, {}
    for _, r in ipairs(Roster()) do
        local mine = MyBlessingOn(r.unit)
        local m = { unit = r.unit, chosen = B.ChosenFamily(r.unit, r.class), mine = mine }
        m.done = Done(m.chosen, mine)
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
            local normalStrength = select(2, B.Best(D.BLESSINGS[family].normal)) or 0
            local useGreater = greaterStrength > normalStrength
                or (greaterStrength == normalStrength and IsInRaid() and lacking >= D.RAID_GREATER_MIN)
            if useGreater and (lacking == 0 or symbols > 0) then
                if lacking > 0 then
                    symbols = symbols - 1
                    queue[#queue + 1] = { spell = spell, unit = target, greater = true, hold = exceptions, class = class }
                end
                for _, m in ipairs(members) do
                    if m.chosen == family and m.fitsGreater then covered[m] = true end
                end
            end
        end
    end

    for _, m in ipairs(order) do
        if m.chosen and not m.done and not covered[m] then
            local spell = B.Best(D.BLESSINGS[m.chosen].normal, m.unit)
            if spell and B.InRange(spell, m.unit) then
                queue[#queue + 1] = { spell = spell, unit = m.unit }
            end
        end
    end
    return queue, Symbols() - symbols
end

-- Whether a unit carries Salvation or Mass Salvation, from anyone. With `renew`, one of mine
-- about to run out counts as absent - for a non-tank; a tank's Revoke sees every Salvation.
local function HasSalvation(unit, renew)
    for _, a in ipairs(B.Auras(unit)) do
        if (a.id == D.SALVATION or a.id == D.MASS_SALVATION) and not (renew and a.mine and Expiring(a)) then
            return true
        end
    end
    return false
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
            local tank = B.RoleOf(r.unit, r.class) == "TANK"
            local m = { unit = r.unit, tank = tank, has = HasSalvation(r.unit, not tank), at = r }
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
            mass[#mass + 1] = { spell = D.MASS_SALVATION, unit = massLacking[1].unit, greater = true,
                                hold = massTanks > 0, class = class }
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

---------------------------------------------------------------------------
-- The overview (ruleset plan 2026-10-19-overview): what a member carries, from whom, and
-- what this paladin would give him next. Out of combat only, as the planner.
---------------------------------------------------------------------------
-- A member as the overview shows him: `carried` maps a blessing family, or "SALVATION" for
-- Salvation and Mass Salvation, to { spell, mine, source, expires }; `next` is { family,
-- spell } or nil; `greyed` when out of reach; `aura`, for a paladin, the aura he runs himself
-- as { spell, source, expires = 0 }. Demo mode reads no auras.
function B.Describe(unit, class)
    local demo = ns.IsDemo()
    local d = { unit = unit, class = class, role = B.RoleOf(unit, class), carried = {} }
    d.visible = demo or UnitIsVisible(unit)
    if d.visible and not demo then
        for _, a in ipairs(B.Auras(unit)) do
            if class == "PALADIN" and B.AURA_FAMILY[a.id] and a.source and UnitIsUnit(a.source, unit) then
                d.aura = { spell = a.id, source = a.source, expires = 0 }
            end
            local rank = RANKS[a.id]
            local key = rank and IS_BLESSING[rank.family] and rank.family
                or (a.id == D.SALVATION or a.id == D.MASS_SALVATION) and "SALVATION"
            if key then
                d.carried[key] = { spell = a.id, mine = a.mine, source = a.source, expires = a.expires }
            end
        end
    end
    local chosen = B.ChosenFamily(unit, class)
    if chosen and not Done(chosen, MyBlessingOn(unit)) then
        local f = D.BLESSINGS[chosen]
        d.next = { family = chosen, spell = B.Best(f.normal, unit) or B.Best(f.greater) }
    end
    -- With no chosen family the range test is skipped
    d.greyed = not B.Eligible(unit) or (d.next ~= nil and not B.InRange(d.next.spell, unit))
    if d.greyed then d.next = nil end
    return d
end

-- The group member a source unit token stands for, or nil when the caster is not in the group
function B.InGroup(source)
    for _, unit in ipairs(B.Members()) do
        if UnitIsUnit(source, unit) then return unit end
    end
end

-- Every member in group order, described; in demo mode the made-up raid (Demo.lua)
function B.Overview()
    if ns.IsDemo() then return ns.DemoRaid() end
    local list = {}
    for _, unit in ipairs(B.Members()) do
        local class = select(2, UnitClass(unit))
        if D.CLASS_LISTS[class or ""] then list[#list + 1] = B.Describe(unit, class) end
    end
    return list
end

---------------------------------------------------------------------------
-- The aura (ruleset plan 2026-10-19-priorities): the first known family on the aura list that
-- no other paladin runs. Out of combat only.
---------------------------------------------------------------------------
local AURA_FAMILY = {}
for family, list in pairs(D.AURAS) do
    for _, id in ipairs(list) do AURA_FAMILY[id] = family end
end
B.AURA_FAMILY = AURA_FAMILY

-- The aura families other paladins run, read from their own buffs: every visible paladin of
-- the group but the player; in a raid only the player's subgroup, as an aura reaches no
-- further. A buff from the player counts nothing, so an aura we share moves this paladin on,
-- as with blessings (Michel, 2026-10-19).
local function TakenAuras()
    local taken = {}
    if ns.IsDemo() then return taken end -- reads no auras; skips the roster too
    local members, subgroup = B.Members(), nil
    if IsInRaid() then
        for i, unit in ipairs(members) do
            if UnitIsUnit(unit, "player") then subgroup = select(3, GetRaidRosterInfo(i)) end
        end
    end
    for i, unit in ipairs(members) do
        if not UnitIsUnit(unit, "player") and select(2, UnitClass(unit)) == "PALADIN" and UnitIsVisible(unit)
           and (not subgroup or select(3, GetRaidRosterInfo(i)) == subgroup) then
            for _, a in ipairs(B.Auras(unit)) do
                if AURA_FAMILY[a.id] and not (a.source and UnitIsUnit(a.source, "player")) then
                    taken[AURA_FAMILY[a.id]] = true
                end
            end
        end
    end
    return taken
end

-- The family the aura button casts: the first known one on the aura list that is not taken;
-- none free, the first known; none known, nil
function B.ChooseAura()
    local taken, firstKnown = TakenAuras(), nil
    for _, family in ipairs(db.auraList) do
        if B.Best(D.AURAS[family]) then
            firstKnown = firstKnown or family
            if not taken[family] then return family end
        end
    end
    return firstKnown
end

---------------------------------------------------------------------------
-- Buff & Run (ruleset plan 2026-10-20-buff-and-run): what the blessing button's middle click
-- casts on its target, any friendly player. Out of combat only.
---------------------------------------------------------------------------
-- Whether the unit carries a blessing of mine, normal or Greater, also one running out: a
-- second would replace it. Salvation and auras take no blessing slot and do not count.
function B.HasMyBlessing(unit)
    for _, a in ipairs(B.Auras(unit)) do
        if a.mine and RANKS[a.id] then return true end
    end
    return false
end

-- The spell for the unit: nil unless it is a friendly player, alive and in reach, carrying
-- no blessing of mine; else the first family of his class's list another paladin has not
-- given, in the best normal rank that fits him - Greater Blessings reach group members only
function B.BuffRunSpell(unit)
    if not B.AurasReadable() then return end
    if not (UnitIsPlayer(unit) and UnitCanAssist("player", unit) and B.Eligible(unit)) then return end
    -- Blessing a PvP-flagged player flags the paladin too: only when allowed (Michel,
    -- 2026-10-20), whether the paladin is flagged or not
    if not db.pvpBlessing and UnitIsPVP(unit) then return end
    if B.HasMyBlessing(unit) then return end
    local list = db.classLists[select(2, UnitClass(unit))]
    if not list then return end
    for _, family in ipairs(list.order) do
        local spell = B.Best(D.BLESSINGS[family].normal, unit)
        if spell and not B.GivenByOthers(unit, family) then
            if B.InRange(spell, unit) then return spell end
            return
        end
    end
end
