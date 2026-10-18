-- The bar's look follows SimpleConjureBar's, so both addons read as one family: backdrop on
-- the bar and every flyout, an arrow on each button with a flyout, a handle that shows only
-- under the mouse, buttons laid out with SimpleConjureBar's size, gap and padding.

local addon = require("addon")

local function login()
    local ns = addon.load("enUS", { group = "party", units = { party1 = { class = "MAGE" } } })
    local A = ns.D.AURAS
    STATE.known = { [A.DEVOTION[1]] = true, [A.RETRIBUTION[1]] = true }
    FIRE("PLAYER_LOGIN")
    return ns, ns.D
end

describe("the look", function()
    it("gives the bar and every flyout SimpleConjureBar's backdrop and color", function()
        local ns, D = login()
        local c = D.BG_COLOR
        for _, frame in ipairs({ ns.bar, ns.flyouts.AURA, ns.flyouts.MAGE }) do
            assert.are.equal(D.BACKDROP, frame.backdrop)
            assert.are.same({ c.r, c.g, c.b, c.a }, frame.backdropColor)
        end
    end)

    it("shows each class as a square icon, cut like the spell icons", function()
        local ns = login()
        local icon = ns.classButtons.MAGE.classIcon
        assert.are.equal("Interface\\Icons\\ClassIcon_MAGE", icon:GetTexture())
        assert.are.same({ 0.07, 0.93, 0.07, 0.93 }, icon.texCoord)
        assert.are.same(ns.auraButton.icon.texCoord, icon.texCoord)
    end)

    it("marks exactly the buttons with a flyout with an arrow", function()
        local ns = login()
        assert.is_truthy(rawget(ns.auraButton, "arrow"))
        assert.is_truthy(rawget(ns.classButtons.MAGE, "arrow"))
        assert.is_nil(rawget(ns.furyButton, "arrow"))
    end)

    it("shows the handle only while the mouse is over it", function()
        local ns = login()
        assert.are.equal(0, ns.handle:GetAlpha())
        RUNSCRIPT(ns.handle, "OnEnter")
        assert.are.equal(1, ns.handle:GetAlpha())
        RUNSCRIPT(ns.handle, "OnLeave")
        assert.are.equal(0, ns.handle:GetAlpha())
    end)

    it("lays the buttons out with SimpleConjureBar's padding and gap", function()
        local ns, D = login()
        local step = D.SIZE + D.GAP
        assert.are.equal(D.PAD, select(4, ns.auraButton:GetPoint()))
        assert.are.equal(D.PAD + step, select(4, ns.furyButton:GetPoint()))
        assert.are.equal(D.PAD + 2 * step, select(4, ns.classButtons.PALADIN:GetPoint()))
        assert.are.equal(D.PAD + 3 * step, select(4, ns.classButtons.MAGE:GetPoint()))
        assert.are.equal(D.PAD + 4 * step - D.GAP + D.PAD, ns.bar:GetWidth())
        -- the flyout's icons start inside its padding
        local icon = ns.flyouts.AURA.icons[1]
        assert.are.equal(D.PAD, select(5, icon:GetPoint()))
    end)
end)
