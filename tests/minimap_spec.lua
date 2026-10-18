-- Minimap.lua: the minimap button, the AddOn compartment and the options entry (ruleset plan
-- 2026-10-18-settings-more, IMPLEMENTATION "Tests, by phase" 4).

local addon = require("addon")

local function login(world)
    local ns = addon.load("enUS", world)
    FIRE("PLAYER_LOGIN")
    return ns, SimpleBlessingBarDB
end

local function lines()
    local out = {}
    for _, l in ipairs(GameTooltip.lines) do out[#out + 1] = l[2] and (l[1] .. "|" .. l[2]) or l[1] end
    return out
end

describe("the minimap button", function()
    it("opens and closes the settings on a left click, and locks on a right click", function()
        local ns, db = login()
        local btn = ns.minimapButton
        assert.are.equal("SimpleBlessingBarMinimapButton", btn:GetName())
        RUNSCRIPT(btn, "OnClick", "LeftButton")
        assert.is_true(ns.UI.window:IsShown())
        RUNSCRIPT(btn, "OnClick", "LeftButton")
        assert.is_false(ns.UI.window:IsShown())
        RUNSCRIPT(btn, "OnClick", "RightButton")
        assert.is_true(db.locked)
        assert.is_truthy(CHAT[#CHAT]:find(ns.L.LOCKED, 1, true))
    end)

    it("shows the TOC's icon", function()
        local ns = login()
        assert.are.equal(C_AddOns.GetAddOnMetadata("SimpleBlessingBar", "IconTexture"), ns.minimapButton.icon:GetTexture())
    end)

    it("moves around the minimap while dragged, and stops on release", function()
        local ns, db = login()
        local btn = ns.minimapButton
        assert.are.equal(ns.D.NUMBER_DEFAULTS.minimapAngle.default, db.minimapAngle)
        local mx, my = Minimap:GetCenter()
        STATE.cursor = { mx, my + 50 } -- straight above the centre
        RUNSCRIPT(btn, "OnDragStart")
        RUNSCRIPT(btn, "OnUpdate", 0.01)
        assert.are.equal(90, db.minimapAngle)
        local p, rel, relP, x, y = btn:GetPoint()
        assert.are.same({ "CENTER", Minimap, "CENTER" }, { p, rel, relP })
        assert.is_true(math.abs(x) < 0.001)
        assert.are.equal(Minimap:GetWidth() / 2 + 10, y)
        RUNSCRIPT(btn, "OnDragStop")
        assert.is_nil(btn:GetScript("OnUpdate"))
    end)

    it("names its clicks and the drag in its tooltip", function()
        local ns = login()
        local L = ns.L
        RUNSCRIPT(ns.minimapButton, "OnEnter")
        assert.are.equal("ANCHOR_LEFT", GameTooltip.anchor)
        assert.is_truthy(GameTooltip:GetText():find(ns.VERSION, 1, true))
        assert.are.same({ " ", L.LEFTCLICK .. "|" .. L.SETTINGS, L.RIGHTCLICK .. "|" .. L.LOCK,
                          L.DRAG .. "|" .. L.MOVE }, lines())
    end)

    it("hides with the General setting, and stays hidden and in place after a login", function()
        local ns, db = login()
        SlashCmdList.SIMPLEBLESSINGBAR("")
        local cb = ns.UI.controls.hideMinimap
        cb:SetChecked(true)
        RUNSCRIPT(cb, "OnClick")
        assert.is_true(db.hideMinimap)
        assert.is_false(ns.minimapButton:IsShown())
        db.minimapAngle = 90
        local again = login({ db = db })
        assert.is_true(SimpleBlessingBarDB.hideMinimap)
        assert.are.equal(90, SimpleBlessingBarDB.minimapAngle)
        assert.is_false(again.minimapButton:IsShown())
    end)
end)

describe("the AddOn compartment", function()
    it("opens the settings, locks, and shows a tooltip without the drag", function()
        local ns, db = login()
        SimpleBlessingBar_OnCompartmentClick(nil, "LeftButton")
        assert.is_true(ns.UI.window:IsShown())
        SimpleBlessingBar_OnCompartmentClick(nil, "RightButton")
        assert.is_true(db.locked)
        local entry = NEWOBJ("Button")
        SimpleBlessingBar_OnCompartmentEnter(nil, entry)
        assert.are.equal(entry, GameTooltip.owner)
        assert.are.equal("ANCHOR_RIGHT", GameTooltip.anchor)
        assert.are.equal(3, #GameTooltip.lines)
        SimpleBlessingBar_OnCompartmentLeave()
        assert.is_false(GameTooltip:IsShown())
    end)

    it("does nothing for any other class, and raises no error", function()
        local ns = addon.load("enUS", { class = "MAGE" })
        FIRE("PLAYER_LOGIN")
        assert.is_nil(ns.CompartmentClick) -- Minimap.lua stopped at its paladin check
        local ok = pcall(function()
            SimpleBlessingBar_OnCompartmentClick(nil, "LeftButton")
            SimpleBlessingBar_OnCompartmentEnter(nil, NEWOBJ("Button"))
            SimpleBlessingBar_OnCompartmentLeave()
        end)
        assert.is_true(ok)
        assert.are.same({}, STATE.errors)
    end)
end)

describe("the options entry", function()
    it("registers a page whose button opens the window above the client's options", function()
        local ns = login()
        assert.are.equal("SimpleBlessingBar", STATE.options.category.name)
        assert.are.equal(STATE.options.category, STATE.options.registered)
        RUNSCRIPT(ns.optionsOpenButton, "OnClick")
        local window = ns.UI.window
        assert.is_true(window:IsShown())
        assert.are.equal("FULLSCREEN_DIALOG", window:GetFrameStrata())
        RUNSCRIPT(ns.optionsOpenButton, "OnClick") -- opens, never closes
        assert.is_true(window:IsShown())
        window:Hide()
        assert.are.equal("DIALOG", window:GetFrameStrata())
    end)
end)
