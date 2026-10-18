-- SimpleBlessingBar - menus
-- Right click on a class button chooses its blessing. The menu is the client's own
-- (MenuUtil); it opens from an insecure click hook, so it works in combat too, and a
-- choice made there takes effect when combat ends.

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings

local db
ns.OnDBReady(function(d) db = d end)

local BLESSING_KEYS = {
    MIGHT = "BLESSING_MIGHT", WISDOM = "BLESSING_WISDOM", KINGS = "BLESSING_KINGS",
    SALVATION = "BLESSING_SALVATION", LIGHT = "BLESSING_LIGHT",
}

-- The blessing families the paladin knows in any rank or form, in menu order
function ns.KnownBlessings()
    local list = {}
    for _, family in ipairs(D.BLESSING_ORDER) do
        local f = D.BLESSINGS[family]
        if B.Rank(f.normal) or B.Rank(f.greater) then list[#list + 1] = family end
    end
    return list
end

function ns.BlessingName(family)
    local f = D.BLESSINGS[family]
    local id = B.Rank(f.normal) or f.normal[1]
    return ns.LocalName(C_Spell.GetSpellName(id), BLESSING_KEYS[family])
end

-- Saves the choice; the bar shows it at once, or after combat (ns.Refresh waits for it)
function ns.Assign(class, family)
    if not D.BLESSINGS[family] then return end
    db.assign[class] = family
    ns.Refresh()
end

function ns.OpenAssignMenu(button)
    local class = button.class
    MenuUtil.CreateContextMenu(button, function(_, root)
        root:CreateTitle(L.MENU_ASSIGN)
        for _, family in ipairs(ns.KnownBlessings()) do
            root:CreateRadio(ns.BlessingName(family),
                function() return db.assign[class] == family end,
                function() ns.Assign(class, family) end)
        end
    end)
end

-- Both key down and up reach OnClick (the buttons register both); the menu opens once,
-- on the up click.
for _, button in pairs(ns.classButtons) do
    button:HookScript("OnClick", function(self, mouseButton, down)
        if mouseButton == "RightButton" and not down then ns.OpenAssignMenu(self) end
    end)
end
