-- SimpleBlessingBar - a member's role set by hand
-- A right click on the blessing button opens a menu for the current target, if it is in the
-- group, else for the player: Automatic, or a role the class can play (ruleset plan
-- 2026-10-19-blessing-steering). Loaded after Flyout.lua: its wraps replace the click script,
-- and a hook set before them would be lost.

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings

-- The member the menu is for: the target when it is in the group, else the player
local function MenuUnit()
    for _, unit in ipairs(B.Members()) do
        if UnitIsUnit(unit, "target") then return unit end
    end
    return "player"
end

-- Built at every opening, so it follows a language switch and the group as it is now
local function OpenMenu(owner)
    local unit = MenuUnit()
    local guid, roles = UnitGUID(unit), D.CLASS_ROLES[select(2, UnitClass(unit))]
    if not guid or not roles then return end
    local function pick(role)
        B.SetHandRole(guid, role)
        ns.Refresh() -- refused in combat; the refresh at its end applies the pick
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.ROLE_MENU)
        -- The name only: UnitName's second value (Forever's second name) would be read as
        -- the title's color
        root:CreateTitle((UnitName(unit)))
        root:CreateRadio(L.ROLE_AUTO, function() return B.HandRole(unit) == nil end, function() pick(nil) end)
        for _, role in ipairs(roles) do
            root:CreateRadio(L["ROLE_" .. role], function() return B.HandRole(unit) == role end, pick, role)
        end
    end)
end

-- On the right button's release, out of combat; the secure attributes stay untouched
ns.blessingButton:HookScript("OnClick", function(self, mouseButton, down)
    if mouseButton ~= "RightButton" or down or InCombatLockdown() then return end
    OpenMenu(self)
end)
