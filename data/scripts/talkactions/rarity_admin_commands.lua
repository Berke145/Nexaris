--[[
    Nexaris Rarity System - GM & Testing Commands
    Usage:
        /rarity set <tier 0..6>
        /rarity roll [slot]
        /rarity awaken [protect 0/1]
        /rarity progress <amount>
        /rarity salvage
        /rarity info
        /rarity give <tier 0..6> [amount]
]]

local talk = TalkAction("/rarity")

local function getTargetEquipment(player)
    local item = player:getSlotItem(CONST_SLOT_LEFT)
    if not item or not Rarity.isEligible(item) then
        item = player:getSlotItem(CONST_SLOT_RIGHT)
    end
    if not item or not Rarity.isEligible(item) then
        for slot = CONST_SLOT_HEAD, CONST_SLOT_FEET do
            local candidate = player:getSlotItem(slot)
            if candidate and Rarity.isEligible(candidate) then
                return candidate, slot
            end
        end
    end
    return item, nil
end

function talk.onSay(player, words, param)
    if not player:getGroup():getAccess() and player:getAccountType() < ACCOUNT_TYPE_GAMEMASTER then
        return false
    end

    if param == "" then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "=== Nexaris Rarity Admin Commands ===")
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "/rarity set <0..6>       - Sets hand item rarity (0=Common..6=Eternal)")
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "/rarity roll [slot]     - Adds bonus or rerolls existing slot")
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "/rarity awaken [0/1]    - Attempts awakening (1=Use Protection)")
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "/rarity progress <val>  - Sets item awakening progress")
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "/rarity salvage         - Salvages hand item into essences")
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "/rarity craft           - Crafts 1x Awakening Protection Stone")
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "/rarity info            - Inspects item custom attributes")
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "/rarity give <tier> [amt] - Gives essences or protection stones")
        return false
    end

    local split = param:splitTrimmed(" ")
    local action = split[1]:lower()

    if action == "refresh" then
        for _, p in ipairs(Game.getPlayers()) do
            Rarity.recalculatePlayerStats(p)
            if p.wheelSendSkillStats then
                p:wheelSendSkillStats(true)
            end
            p:sendStats()
        end
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "[Rarity] All online players' stats and skills resynchronized.")
        return false
    end

    if action == "craft" then
        local success, msg = Rarity.craftProtectionStone(player)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, msg)
        return false
    end

    if action == "give" then
        local tier = tonumber(split[2]) or 0
        local amount = tonumber(split[3]) or 10
        if tier == 7 then -- 7 = Protection Stone
            local protId = Rarity.PROTECTION_MATERIAL.itemId
            player:addItem(protId, amount)
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Received %d %s.", amount, Rarity.PROTECTION_MATERIAL.name))
        else
            local essenceInfo = Rarity.ESSENCE_ITEMS[tier]
            if essenceInfo then
                player:addItem(essenceInfo.itemId, amount)
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Received %d %s.", amount, essenceInfo.name))
            else
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Invalid tier (0..6, or 7 for Protection Stone).")
            end
        end
        return false
    end

    local targetItem, slot = getTargetEquipment(player)
    if not targetItem then
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Hold an eligible equipment item in your hand first.")
        return false
    end

    if action == "set" then
        local tier = tonumber(split[2]) or 0
        if tier < Rarity.TIERS.COMMON or tier > Rarity.TIERS.ETERNAL then
            player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Tier must be between 0 (Common) and 6 (Eternal).")
            return false
        end

        Rarity.applyTierToItem(targetItem, tier, false)
        if slot then
            Rarity.applySlotBonuses(player, targetItem, slot)
            if player.wheelSendSkillStats then player:wheelSendSkillStats() end
            player:sendStats()
        end
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Item set to tier %s (%s).", tier, Rarity.TIER_INFO[tier].name))

    elseif action == "roll" then
        local targetSlot = tonumber(split[2])
        local success, msg = Rarity.rollItemBonus(player, targetItem, targetSlot)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, msg)
        if slot then
            Rarity.applySlotBonuses(player, targetItem, slot)
            if player.wheelSendSkillStats then player:wheelSendSkillStats() end
            player:sendStats()
        end

    elseif action == "awaken" then
        local useProtect = (tonumber(split[2]) or 0) == 1
        local success, msg = Rarity.awakenItem(player, targetItem, useProtect)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, msg)
        if slot then
            Rarity.applySlotBonuses(player, targetItem, slot)
            if player.wheelSendSkillStats then player:wheelSendSkillStats() end
            player:sendStats()
        end

    elseif action == "progress" then
        local val = tonumber(split[2]) or 0
        Rarity.setItemProgress(targetItem, val)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Awakening progress set to %d.", val))

    elseif action == "salvage" then
        local success, msg = Rarity.salvageItem(player, targetItem)
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, msg)

    elseif action == "info" then
        local tier = Rarity.getItemTier(targetItem)
        local progress = Rarity.getItemProgress(targetItem)
        local bonuses = Rarity.getBonuses(targetItem)
        local tierInfo = Rarity.TIER_INFO[tier]

        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Item: %s | Tier: %d (%s) | Progress: %d",
            targetItem:getName(), tier, tierInfo.name, progress))

        for s = 1, tierInfo.maxSlots do
            local b = bonuses[s]
            if b then
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("  Slot %d: %s = %d", s, b.id, b.val))
            else
                player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("  Slot %d: [EMPTY]", s))
            end
        end

    else
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, "Unknown sub-command. Type /rarity for help.")
    end

    return false
end

talk:separator(" ")
talk:register()
