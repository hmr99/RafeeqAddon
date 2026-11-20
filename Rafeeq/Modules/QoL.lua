-- Rafeeq: quality-of-life helpers
--  * auto repair + sell grey items at vendors
--  * keep action bar spells on their highest rank after training (out of combat)
--  * level-up trainer reminder
--  * XP per hour and time-to-level estimate
local _, ns = ...

local QoL = ns:NewModule("QoL")
ns.QoL = QoL

local function money(c)
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return ("%dg %ds %dc"):format(c / 10000, (c / 100) % 100, c % 100)
end

---------------------------------------------------------------------------
-- Vendor
---------------------------------------------------------------------------
local sellQueue, selling = {}, false

local function sellNext()
    if not MerchantFrame or not MerchantFrame:IsShown() then wipe(sellQueue) selling = false return end
    local item = table.remove(sellQueue, 1)
    if not item then selling = false return end
    local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
    if info and info.quality == 0 and info.hyperlink == item.link then
        C_Container.UseContainerItem(item.bag, item.slot)
    end
    C_Timer.After(0.15, sellNext) -- staggered so the server never drops a sale
end

local function onMerchant()
    if IsShiftKeyDown() then return end
    if ns.db.autoSell and C_Container then
        local total, count = 0, 0
        wipe(sellQueue)
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.quality == 0 and not info.hasNoValue and info.hyperlink then
                    local price = select(11, GetItemInfo(info.hyperlink)) or 0
                    if price > 0 then
                        total = total + price * (info.stackCount or 1)
                        count = count + 1
                        sellQueue[#sellQueue + 1] = { bag = bag, slot = slot, link = info.hyperlink }
                    end
                end
            end
        end
        if count > 0 then
            ns.Print("SOLD_GREYS", count, money(total))
            if not selling then selling = true sellNext() end
        end
    end
    if ns.db.autoRepair and CanMerchantRepair and CanMerchantRepair() then
        local cost, need = GetRepairAllCost()
        if need and cost > 0 then
            local guildOK = ns.db.guildRepair and CanGuildBankRepair and CanGuildBankRepair()
                and GetGuildBankWithdrawMoney and (GetGuildBankWithdrawMoney() == -1 or GetGuildBankWithdrawMoney() >= cost)
            if guildOK then
                RepairAllItems(true)
                ns.Print("REPAIRED_GUILD", money(cost))
            elseif GetMoney() >= cost then
                RepairAllItems()
                ns.Print("REPAIRED", money(cost))
            else
                ns.Print("REPAIR_NO_MONEY", money(cost))
            end
        end
    end
end

---------------------------------------------------------------------------
-- Highest-rank updater for action bars
---------------------------------------------------------------------------
local function highestRank(spellID)
    local name
    if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(spellID)
    elseif GetSpellInfo then name = GetSpellInfo(spellID) end
    if not name then return nil end
    -- looking a spell up by name returns the highest rank you know
    local id
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        id = info and info.spellID
    elseif GetSpellInfo then
        id = select(7, GetSpellInfo(name))
    end
    return id
end

local pendingRanks = false
local function updateRanks()
    if not ns.db.autoRank then return end
    if InCombatLockdown() then pendingRanks = true return end
    pendingRanks = false
    local changed = 0
    for slot = 1, 120 do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and id then
            local best = highestRank(id)
            if best and best ~= id then
                local pickup = (C_Spell and C_Spell.PickupSpell) or PickupSpell
                pickup(best)
                if GetCursorInfo() == "spell" then
                    PlaceAction(slot)
                    ClearCursor()
                    changed = changed + 1
                end
            end
        end
    end
    if changed > 0 then ns.Print("RANKS_UPDATED", changed) end
end

---------------------------------------------------------------------------
-- XP rate
---------------------------------------------------------------------------
local startTime, gained, lastXP, lastMax

local function onXP()
    local xp, max = UnitXP("player"), UnitXPMax("player")
    if lastXP then
        if xp >= lastXP then gained = gained + (xp - lastXP)
        else gained = gained + (lastMax - lastXP) + xp end -- level up
    end
    lastXP, lastMax = xp, max
end

-- seconds to next level, or nil
function QoL:TimeToLevel()
    if not startTime or gained < 1 then return nil end
    local elapsed = GetTime() - startTime
    if elapsed < 120 then return nil end
    local rate = gained / elapsed
    local need = UnitXPMax("player") - UnitXP("player")
    return need / rate, rate * 3600
end

---------------------------------------------------------------------------
function QoL:OnInit()
    ns:On("MERCHANT_SHOW", onMerchant)
    ns:On("PLAYER_ENTERING_WORLD", function()
        if not startTime then
            startTime, gained = GetTime(), 0
            lastXP, lastMax = UnitXP("player"), UnitXPMax("player")
        end
    end)
    ns:On("PLAYER_XP_UPDATE", onXP)
    ns:On("LEARNED_SPELL_IN_TAB", function() C_Timer.After(0.5, updateRanks) end)
    pcall(ns.On, ns, "LEARNED_SPELL_IN_SKILL_LINE", function() C_Timer.After(0.5, updateRanks) end)
    ns:On("PLAYER_REGEN_ENABLED", function() if pendingRanks then updateRanks() end end)
    ns:On("PLAYER_LEVEL_UP", function(_, level)
        if ns.db.trainerReminder and level and level % 2 == 0 then ns.Print("TRAINER_REMINDER", level) end
    end)
end

QoL.UpdateRanks = updateRanks
