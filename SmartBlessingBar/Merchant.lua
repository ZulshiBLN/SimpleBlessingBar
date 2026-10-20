-- SmartBlessingBar - Symbol of Kings auto-buy
-- At a vendor the missing amount up to the target is bought, as in SimpleConjureBar, but only
-- while a Greater Blessing is known and only as far as the gold above the reserve reaches
-- (ruleset plan 2026-10-18-settings-more). On Forever BuyMerchantItem counts single items and
-- the listed price is per vendor stack (ruleset decisions, 2026-10-18).

local _, ns = ...
if not ns.enabled then return end

local D, L, B = ns.D, ns.L, ns.Blessings

local db
ns.OnDBReady(function(d) db = d end)

local function MoneyText(copper) return C_CurrencyInfo.GetCoinTextureString(copper) end

local function SymbolName()
    return ns.LocalName(C_Item.GetItemNameByID(D.SYMBOL_OF_KINGS), "SYMBOL_OF_KINGS")
end

local lastBuy = -D.BUY_LOCK

local function AutoBuy()
    -- A vendor reopened right after a purchase: the bags may not count it yet
    if GetTime() - lastBuy < D.BUY_LOCK then return end
    if not B.AnyGreaterKnown() then return end

    -- Only the difference to the target, from the real bags - in demo mode too
    local need = db.symbolAmount - C_Item.GetItemCount(D.SYMBOL_OF_KINGS)
    if need <= 0 then return end
    for i = 1, GetMerchantNumItems() do
        if GetMerchantItemID(i) == D.SYMBOL_OF_KINGS then
            local info = C_MerchantFrame.GetItemInfo(i)
            if not info then return end -- the client may not have the entry loaded yet
            local batch = (info.stackCount and info.stackCount > 0) and info.stackCount or 1
            local unit = (info.price or 0) / batch
            -- Never an item without a gold price (another currency)
            if unit <= 0 then return end
            local budget = GetMoney() - db.goldReserve * 10000
            local affordable = math.max(0, math.floor(budget / unit))
            local reserveHit = affordable < need
            need = math.min(need, affordable)
            if need > 0 then
                local name = SymbolName()
                if ns.IsDemo() then
                    ns.DemoPrint(L.DEMO_BUY, need, name)
                    ns.DemoPrint(L.DEMO_COST, MoneyText(math.floor(need * unit)))
                else
                    local maxStack = math.max(1, GetMerchantItemMaxStack(i))
                    local left = need
                    while left > 0 do
                        local n = math.min(left, maxStack)
                        BuyMerchantItem(i, n)
                        left = left - n
                    end
                    -- Only requested here; full bags can still refuse it
                    ns.Print(L.BUYING:format(need, name))
                    ns.Print(L.COST:format(MoneyText(math.floor(need * unit))))
                    lastBuy = GetTime()
                end
            end
            if reserveHit and db.goldReserve > 0 then
                ns.Print(L.RESERVE_REACHED:format(MoneyText(db.goldReserve * 10000)))
            end
            return
        end
    end
end

-- Some vendors fill their list after MERCHANT_SHOW; then the purchase runs once on the first
-- MERCHANT_UPDATE instead, never twice.
local waitingForList = false
local events = CreateFrame("Frame")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_UPDATE")
events:RegisterEvent("MERCHANT_CLOSED")
events:SetScript("OnEvent", function(_, event)
    if not db then return end
    if event == "MERCHANT_SHOW" then
        waitingForList = false
        if not db.autoBuy then return end
        if GetMerchantNumItems() > 0 then AutoBuy() else waitingForList = true end
    elseif event == "MERCHANT_UPDATE" then
        if waitingForList and GetMerchantNumItems() > 0 then
            waitingForList = false
            if db.autoBuy then AutoBuy() end
        end
    else
        waitingForList = false
    end
end)
