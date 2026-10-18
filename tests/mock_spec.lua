-- The mock's secure snippets and clicks behave as the client's do, as far as the flyouts
-- rely on it (ruleset plan 2026-10-18-flyouts, IMPLEMENTATION "Tests, by phase" 1).
-- Each case is one rule of the client's WrapScript and SecureActionButtonTemplate.

local addon = require("addon")

-- A fresh mock with a header and one secure button wrapped by it
local function setup(pre, post)
    addon.load("enUS")
    local header = CreateFrame("Frame", "MockHeader", UIParent, "SecureHandlerBaseTemplate")
    local button = CreateFrame("Button", "MockButton", UIParent, "SecureActionButtonTemplate")
    button:SetAttribute("type1", "spell")
    button:SetAttribute("spell1", 100)
    button:SetAttribute("unit1", "player")
    header:WrapScript(button, "OnClick", pre, post)
    return header, button
end

describe("a wrapped secure click in the mock", function()
    it("casts on key down when the pre body lets it through", function()
        local _, button = setup([[ return nil, "go" ]])
        RUNCLICK(button, "LeftButton", true)
        RUNCLICK(button, "LeftButton", false)
        assert.are.same({ { spell = 100, unit = "player" } }, STATE.casts)
        assert.are.same({}, STATE.errors)
    end)

    it("casts on key up instead while ActionButtonUseKeyDown is off", function()
        local _, button = setup([[ return nil, "go" ]])
        STATE.keyDown = false
        RUNCLICK(button, "LeftButton", true)
        assert.are.equal(0, #STATE.casts)
        RUNCLICK(button, "LeftButton", false)
        assert.are.equal(1, #STATE.casts)
    end)

    it("stops the action and the post body when the pre body returns false", function()
        local _, button = setup([[ return false ]], [[ self:SetAttribute("posted", true) ]])
        RUNCLICK(button, "LeftButton", true)
        assert.are.equal(0, #STATE.casts)
        assert.is_nil(button:GetAttribute("posted"))
    end)

    it("runs the post body only with a message, and hands the message over", function()
        -- A constant: setting `message` would read nil whether the body ran or not
        local _, silent = setup([[ return ]], [[ self:SetAttribute("posted", "ran") ]])
        RUNCLICK(silent, "LeftButton", true)
        assert.are.equal(1, #STATE.casts)
        assert.is_nil(silent:GetAttribute("posted"))

        local _, button = setup([[ return nil, "chosen" ]], [[ self:SetAttribute("posted", message) ]])
        RUNCLICK(button, "LeftButton", true)
        assert.are.equal("chosen", button:GetAttribute("posted"))
    end)

    it("lets a snippet show a protected frame in combat, which addon code may not", function()
        local header, button = setup([[
            owner:GetFrameRef("target"):Show()
            return false
        ]])
        local protected = CreateFrame("Frame", "MockFlyout", UIParent)
        CreateFrame("Button", "MockChild", protected, "SecureActionButtonTemplate")
        header:SetFrameRef("target", protected)
        protected.shown = false
        STATE.combat = true
        assert.has_error(function() protected:Show() end)
        RUNCLICK(button, "RightButton", false)
        assert.is_true(protected:IsShown())
        assert.are.same({}, STATE.errors)
    end)

    it("takes type1 for the left button, type2 for the right, and plain type for both", function()
        local _, button = setup()
        button:SetAttribute("type2", "spell")
        button:SetAttribute("spell2", 200)
        RUNCLICK(button, "RightButton", true)
        assert.are.equal(200, STATE.casts[1].spell)

        local _, plain = setup()
        plain:SetAttribute("type1", nil)
        plain:SetAttribute("type", "spell")
        plain:SetAttribute("spell", 300)
        RUNCLICK(plain, "RightButton", true)
        assert.are.equal(300, STATE.casts[1].spell)
    end)

    it("allows the auto-hide only on a protected frame, and adds frames only after registering", function()
        local header, button = setup([[
            local plain = owner:GetFrameRef("plain")
            plain:RegisterAutoHide(2)
            return false
        ]])
        header:SetFrameRef("plain", CreateFrame("Frame", "MockPlain", UIParent))
        RUNCLICK(button, "RightButton", false)
        assert.is_truthy(STATE.errors[1] and STATE.errors[1]:find("unprotected", 1, true))

        local header2, button2 = setup([[
            local fly = owner:GetFrameRef("fly")
            fly:AddToAutoHide(self)
            return false
        ]])
        local fly = CreateFrame("Frame", "MockFly", UIParent)
        CreateFrame("Button", "MockFlyChild", fly, "SecureActionButtonTemplate")
        header2:SetFrameRef("fly", fly)
        RUNCLICK(button2, "RightButton", false)
        assert.is_truthy(STATE.errors[1] and STATE.errors[1]:find("before RegisterAutoHide", 1, true))
    end)

    it("refuses a handle to an unprotected frame in combat, as the client does", function()
        local header, button = setup([[
            owner:GetFrameRef("plain"):IsShown()
            return false
        ]])
        header:SetFrameRef("plain", CreateFrame("Frame", "MockPlain2", UIParent))
        RUNCLICK(button, "RightButton", false)
        assert.are.same({}, STATE.errors)
        STATE.combat = true
        RUNCLICK(button, "RightButton", false)
        assert.is_truthy(STATE.errors[1] and STATE.errors[1]:find("Invalid frame handle", 1, true))
    end)

    it("runs insecure hooks after the secure action", function()
        local _, button = setup([[ return nil, "go" ]])
        local seen
        button:HookScript("OnClick", function() seen = #STATE.casts end)
        RUNCLICK(button, "LeftButton", true)
        assert.are.equal(1, seen)
    end)
end)
