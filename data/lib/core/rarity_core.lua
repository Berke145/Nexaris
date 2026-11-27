--[[
    Nexaris Rarity System - Core Library
    Clean-room implementation for TFS 1.8 Downgrade (Protocol 8.60)
]]

Rarity = Rarity or {}

-- Checks if an item is eligible for the rarity system
function Rarity.isEligible(item)
    if not item or not item:isItem() then
        return false
    end

    local itemType = item:getType()
    if not itemType then
        return false
    end

    -- Stackable items, containers, fluids, and keys are strictly excluded
    if itemType:isStackable() or itemType:isContainer() then
        return false
    end

    local group = itemType:getGroup()
    if group == ITEM_GROUP_FLUID or group == ITEM_GROUP_SPLASH or group == ITEM_GROUP_DEPRECATED then
        return false
    end

    if itemType.isFluidContainer and itemType:isFluidContainer() then
        return false
    end

    if itemType.isKey and itemType:isKey() then
        return false
    end

    -- Must occupy an equipment slot
    local slotPosition = itemType:getSlotPosition()
    if not slotPosition or slotPosition == 0 then
        return false
    end

    -- Check if it matches allowed equipment categories
    local category = Rarity.getItemCategory(item)
    return category ~= nil
end

-- Identifies the item equipment category
function Rarity.getItemCategory(item)
    local itemType = item:isItem() and item:getType() or item
    if not itemType then
        return nil
    end

    local weaponType = itemType:getWeaponType()
    if weaponType and weaponType ~= WEAPON_NONE and weaponType ~= WEAPON_SHIELD then
        return "weapon"
    end

    if weaponType == WEAPON_SHIELD then
        return "shield"
    end

    local slotPos = itemType:getSlotPosition()
    if (slotPos & SLOTP_HEAD) ~= 0 then
        return "helmet"
    elseif (slotPos & SLOTP_ARMOR) ~= 0 then
        return "armor"
    elseif (slotPos & SLOTP_LEGS) ~= 0 then
        return "legs"
    elseif (slotPos & SLOTP_FEET) ~= 0 then
        return "boots"
    elseif (slotPos & SLOTP_NECKLACE) ~= 0 then
        return "jewelry"
    elseif (slotPos & SLOTP_RING) ~= 0 then
        return "jewelry"
    end

    return nil
end

-- Reads the item rarity tier (defaults to COMMON = 0)
function Rarity.getItemTier(item)
    if not item or not item:isItem() then
        return Rarity.TIERS.COMMON
    end

    local tier = item:getCustomAttribute("rarity_tier")
    if not tier or type(tier) ~= "number" then
        return Rarity.TIERS.COMMON
    end

    return math.max(Rarity.TIERS.COMMON, math.min(Rarity.TIERS.ETERNAL, math.floor(tier)))
end

-- Sets the item rarity tier
function Rarity.setItemTier(item, tier)
    if not item or not item:isItem() then
        return false
    end

    tier = math.max(Rarity.TIERS.COMMON, math.min(Rarity.TIERS.ETERNAL, math.floor(tier or 0)))
    item:setCustomAttribute("rarity_tier", tier)
    return true
end

-- Reads Awakening Progress on the item (Pity Counter)
function Rarity.getItemProgress(item)
    if not item or not item:isItem() then
        return 0
    end

    local prog = item:getCustomAttribute("rarity_progress")
    if not prog or type(prog) ~= "number" then
        return 0
    end

    return math.max(0, math.floor(prog))
end

-- Sets Awakening Progress on the item
function Rarity.setItemProgress(item, progress)
    if not item or not item:isItem() then
        return false
    end

    progress = math.max(0, math.floor(progress or 0))
    if progress == 0 then
        item:removeCustomAttribute("rarity_progress")
    else
        item:setCustomAttribute("rarity_progress", progress)
    end
    return true
end

-- Retrieves all active rarity bonuses from an item
function Rarity.getBonuses(item)
    local bonuses = {}
    if not item or not item:isItem() then
        return bonuses
    end

    local tier = Rarity.getItemTier(item)
    local maxSlots = Rarity.TIER_INFO[tier] and Rarity.TIER_INFO[tier].maxSlots or 0
    if maxSlots == 0 then
        return bonuses
    end

    for slot = 1, maxSlots do
        local bonusId = item:getCustomAttribute("rarity_bonus_" .. slot .. "_id")
        local bonusVal = item:getCustomAttribute("rarity_bonus_" .. slot .. "_val")
        if bonusId and bonusVal and Rarity.BONUS_DEFINITIONS[bonusId] then
            bonuses[slot] = {
                id = tostring(bonusId),
                val = tonumber(bonusVal) or 0
            }
        end
    end

    return bonuses
end

-- Sets a bonus into a specific slot index
function Rarity.setBonus(item, slotIndex, bonusId, bonusVal)
    if not item or not item:isItem() or not slotIndex or slotIndex < 1 or slotIndex > 6 then
        return false
    end

    if not bonusId or not bonusVal or not Rarity.BONUS_DEFINITIONS[bonusId] then
        item:removeCustomAttribute("rarity_bonus_" .. slotIndex .. "_id")
        item:removeCustomAttribute("rarity_bonus_" .. slotIndex .. "_val")
        return true
    end

    item:setCustomAttribute("rarity_bonus_" .. slotIndex .. "_id", tostring(bonusId))
    item:setCustomAttribute("rarity_bonus_" .. slotIndex .. "_val", tonumber(bonusVal) or 0)
    return true
end

-- Clears all bonus slots from an item
function Rarity.clearBonuses(item)
    if not item or not item:isItem() then
        return false
    end

    for slot = 1, 6 do
        item:removeCustomAttribute("rarity_bonus_" .. slot .. "_id")
        item:removeCustomAttribute("rarity_bonus_" .. slot .. "_val")
    end
    return true
end

-- Counts how many slots are currently populated
function Rarity.getFilledSlotCount(item)
    local bonuses = Rarity.getBonuses(item)
    local count = 0
    for _ in pairs(bonuses) do
        count = count + 1
    end
    return count
end

-- Finds the next empty slot index for an item based on its tier capacity
function Rarity.getNextEmptySlot(item)
    local tier = Rarity.getItemTier(item)
    local maxSlots = Rarity.TIER_INFO[tier] and Rarity.TIER_INFO[tier].maxSlots or 0
    local bonuses = Rarity.getBonuses(item)

    for slot = 1, maxSlots do
        if not bonuses[slot] then
            return slot
        end
    end
    return nil -- All tier slots are filled
end

-- Rolls a random bonus ID and value appropriate for the category and tier
function Rarity.rollBonusForCategory(category, tier, excludeBonusIds)
    excludeBonusIds = excludeBonusIds or {}
    local validBonuses = {}

    for bonusId, def in pairs(Rarity.BONUS_DEFINITIONS) do
        if not excludeBonusIds[bonusId] then
            local categoryMatch = false
            for _, cat in ipairs(def.categories) do
                if cat == category or (cat == "jewelry" and (category == "necklace" or category == "ring" or category == "jewelry")) then
                    categoryMatch = true
                    break
                end
            end

            if categoryMatch and def.ranges[tier] then
                table.insert(validBonuses, bonusId)
            end
        end
    end

    if #validBonuses == 0 then
        return nil, 0
    end

    local chosenBonusId = validBonuses[math.random(1, #validBonuses)]
    local range = Rarity.BONUS_DEFINITIONS[chosenBonusId].ranges[tier]
    local value = math.random(range.min, range.max)

    return chosenBonusId, value
end

-- Applies a tier to an item and populates bonus slots
function Rarity.applyTierToItem(item, tier, preserveExisting)
    if not item or not item:isItem() then
        return false
    end

    tier = math.max(Rarity.TIERS.COMMON, math.min(Rarity.TIERS.ETERNAL, math.floor(tier)))
    Rarity.setItemTier(item, tier)

    local category = Rarity.getItemCategory(item)
    if not category then
        return false
    end

    local maxSlots = Rarity.TIER_INFO[tier] and Rarity.TIER_INFO[tier].maxSlots or 0
    local existingBonuses = preserveExisting and Rarity.getBonuses(item) or {}

    if not preserveExisting then
        Rarity.clearBonuses(item)
    end

    local excludeBonusIds = {}
    for _, b in pairs(existingBonuses) do
        excludeBonusIds[b.id] = true
    end

    -- Fill up to maxSlots
    for slot = 1, maxSlots do
        if not existingBonuses[slot] then
            local bonusId, val = Rarity.rollBonusForCategory(category, tier, excludeBonusIds)
            if bonusId and val > 0 then
                Rarity.setBonus(item, slot, bonusId, val)
                excludeBonusIds[bonusId] = true
            end
        end
    end

    return true
end

-- Builds a clean multi-line description text for item look/inspections
function Rarity.formatDescription(item)
    return ""
end

-- Modifies the full item look description:
-- 1. Prepends lowercase rarity to item title (e.g. "You see an eternal solar axe", "You see a legendary magic sword")
-- 2. Updates base (Atk:.. Def:.. Arm:..) values by adding the flat bonuses
-- 3. Appends an empty line and neatly indented [Bonus: +Val] lines exactly like the user's reference image
function Rarity.modifyLookDescription(item, description)
    if not item or not item:isItem() then
        return description
    end

    local tier = Rarity.getItemTier(item)
    if tier == Rarity.TIERS.COMMON then
        return description
    end

    local tierInfo = Rarity.TIER_INFO[tier]
    if not tierInfo then
        return description
    end

    local tierPrefix = tierInfo.name:lower()
    local isVowel = tierPrefix:match("^[aeiou]") ~= nil
    local article = isVowel and "an" or "a"

    -- 1. Replace "You see a " / "You see an " / "You see "
    if description:find("^You see an? ") then
        description = description:gsub("^You see an? ", "You see " .. article .. " " .. tierPrefix .. " ", 1)
    elseif description:find("^You see ") then
        description = description:gsub("^You see ", "You see " .. article .. " " .. tierPrefix .. " ", 1)
    end

    local bonuses = Rarity.getBonuses(item)

    -- 2. Modify base Atk / Def / Arm numbers in parentheses (e.g. Atk:48 + 7 -> Atk:55)
    for _, b in pairs(bonuses) do
        if b.id == "flat_atk" and b.val and b.val > 0 then
            description = description:gsub("Atk:(%d+)", function(atk)
                return "Atk:" .. (tonumber(atk) + b.val)
            end, 1)
            description = description:gsub("Atk%+(%d+)", function(atk)
                return "Atk+" .. (tonumber(atk) + b.val)
            end, 1)
        elseif b.id == "flat_def" and b.val and b.val > 0 then
            description = description:gsub("Def:(%d+)", function(def)
                return "Def:" .. (tonumber(def) + b.val)
            end, 1)
        elseif b.id == "flat_arm" and b.val and b.val > 0 then
            description = description:gsub("Arm:(%d+)", function(arm)
                return "Arm:" .. (tonumber(arm) + b.val)
            end, 1)
        end
    end

    -- 3. Append cleanly formatted bonus lines after an empty line (matching reference image)
    local bonusLines = {}
    for slot = 1, tierInfo.maxSlots do
        local b = bonuses[slot]
        if b then
            local def = Rarity.BONUS_DEFINITIONS[b.id]
            if def and def.format then
                table.insert(bonusLines, string.format("    [%s]", string.format(def.format, b.val)))
            end
        else
            table.insert(bonusLines, "    [Empty Slot]")
        end
    end

    -- Awakening progress display
    if tierInfo.canAwaken then
        local progress = Rarity.getItemProgress(item)
        local awakenConfig = Rarity.AWAKENING_CONFIG[tier]
        if awakenConfig then
            table.insert(bonusLines, string.format("    [Awakening Progress: %d/%d]", progress, awakenConfig.pityThreshold))
        end
    end

    if #bonusLines > 0 then
        description = description .. "\n\n" .. table.concat(bonusLines, "\n")
    end

    return description
end

-- Salvages an item into essence of the same rarity tier
function Rarity.salvageItem(player, item)
    if not player or not item or not item:isItem() then
        return false, "Invalid item."
    end

    if not Rarity.isEligible(item) then
        return false, "This item cannot be salvaged."
    end

    local tier = Rarity.getItemTier(item)
    local essenceInfo = Rarity.ESSENCE_ITEMS[tier]
    if not essenceInfo then
        return false, "Unknown essence tier."
    end

    local yieldConfig = Rarity.SALVAGE_CONFIG.YIELDS[tier]
    local category = Rarity.getItemCategory(item)
    local slotMult = Rarity.SALVAGE_CONFIG.SLOT_MULTIPLIERS[category] or 1.0

    local amount = math.max(1, math.floor(math.random(yieldConfig.min, yieldConfig.max) * slotMult))

    -- Remove item
    item:remove(1)

    -- Reward essence
    player:addItem(essenceInfo.itemId, amount)

    local tierName = Rarity.TIER_INFO[tier].name
    return true, string.format("You salvaged a %s equipment and received %d %s.", tierName, amount, essenceInfo.name)
end

-- Adds a new bonus or rerolls an existing slot without raising the item's rarity
function Rarity.rollItemBonus(player, item, forceRerollSlot)
    if not player or not item or not item:isItem() then
        return false, "Invalid item."
    end

    if not Rarity.isEligible(item) then
        return false, "This item is not eligible for rarity rolls."
    end

    local tier = Rarity.getItemTier(item)
    if tier == Rarity.TIERS.COMMON then
        return false, "Common items have 0 bonus slots and cannot be rolled."
    end

    local tierInfo = Rarity.TIER_INFO[tier]
    local category = Rarity.getItemCategory(item)
    local emptySlot = Rarity.getNextEmptySlot(item)

    local isAddMode = (emptySlot ~= nil and not forceRerollSlot)
    local costConfig = isAddMode and Rarity.RANDOM_ROLL_CONFIG.ADD_SLOT_COST[tier] or Rarity.RANDOM_ROLL_CONFIG.REROLL_SLOT_COST[tier]
    local essenceInfo = Rarity.ESSENCE_ITEMS[tier]

    if not costConfig or not essenceInfo then
        return false, "Invalid roll configuration for this tier."
    end

    -- Cost validation
    if player:getItemCount(essenceInfo.itemId) < costConfig.essence then
        return false, string.format("You need %d %s to perform this roll.", costConfig.essence, essenceInfo.name)
    end

    local currentMoney = player:getMoney() + player:getBankBalance()
    if currentMoney < costConfig.gold then
        return false, string.format("You need %d gold to perform this roll.", costConfig.gold)
    end

    -- Deduct costs
    player:removeItem(essenceInfo.itemId, costConfig.essence)
    player:removeMoneyBank(costConfig.gold)

    local existingBonuses = Rarity.getBonuses(item)
    local excludeBonusIds = {}
    for _, b in pairs(existingBonuses) do
        excludeBonusIds[b.id] = true
    end

    if isAddMode then
        -- Fill the next empty slot
        local bonusId, val = Rarity.rollBonusForCategory(category, tier, excludeBonusIds)
        if not bonusId or val <= 0 then
            return false, "Failed to roll an applicable bonus."
        end

        Rarity.setBonus(item, emptySlot, bonusId, val)
        return true, string.format("Added bonus to slot %d: %s!", emptySlot, string.format(Rarity.BONUS_DEFINITIONS[bonusId].format, val))
    else
        -- Reroll existing slot
        local slotToReroll = forceRerollSlot or math.random(1, tierInfo.maxSlots)
        local oldBonus = existingBonuses[slotToReroll]
        if oldBonus then
            excludeBonusIds[oldBonus.id] = nil -- Allow rolling something different
        end

        local bonusId, val = Rarity.rollBonusForCategory(category, tier, excludeBonusIds)
        if not bonusId or val <= 0 then
            return false, "Failed to reroll bonus."
        end

        Rarity.setBonus(item, slotToReroll, bonusId, val)
        return true, string.format("Rerolled slot %d: %s!", slotToReroll, string.format(Rarity.BONUS_DEFINITIONS[bonusId].format, val))
    end
end

-- Awakening System: Upgrades Legendary -> Mythic -> Eternal with Pity and Protection
function Rarity.awakenItem(player, item, useProtection)
    if not player or not item or not item:isItem() then
        return false, "Invalid item."
    end

    if not Rarity.isEligible(item) then
        return false, "This item cannot be awakened."
    end

    local tier = Rarity.getItemTier(item)
    local awakenConfig = Rarity.AWAKENING_CONFIG[tier]
    if not awakenConfig then
        return false, "Only Legendary and Mythic items can be awakened."
    end

    local tierInfo = Rarity.TIER_INFO[tier]
    local targetTier = awakenConfig.targetTier
    local targetTierInfo = Rarity.TIER_INFO[targetTier]
    local essenceInfo = Rarity.ESSENCE_ITEMS[tier]

    -- Material & Gold validation
    if player:getItemCount(essenceInfo.itemId) < awakenConfig.essenceCost then
        return false, string.format("You need %d %s for awakening.", awakenConfig.essenceCost, essenceInfo.name)
    end

    local currentMoney = player:getMoney() + player:getBankBalance()
    if currentMoney < awakenConfig.goldCost then
        return false, string.format("You need %d gold for awakening.", awakenConfig.goldCost)
    end

    -- Protection stone validation
    local hasProtectionStone = false
    local protMaterial = Rarity.PROTECTION_MATERIAL
    if useProtection then
        if player:getItemCount(protMaterial.itemId) > 0 then
            hasProtectionStone = true
        else
            return false, string.format("You do not have a %s for protection.", protMaterial.name)
        end
    end

    -- Deduct common costs
    player:removeItem(essenceInfo.itemId, awakenConfig.essenceCost)
    player:removeMoneyBank(awakenConfig.goldCost)
    if hasProtectionStone then
        player:removeItem(protMaterial.itemId, 1)
    end

    local currentProgress = Rarity.getItemProgress(item)
    local isGuaranteed = (currentProgress >= awakenConfig.pityThreshold)
    local roll = math.random(1, 100)
    local isSuccess = isGuaranteed or (roll <= awakenConfig.successChance)

    if isSuccess then
        -- Success: upgrade tier, preserve existing bonuses, reset progress
        Rarity.applyTierToItem(item, targetTier, true)
        Rarity.setItemProgress(item, 0)

        player:getPosition():sendMagicEffect(CONST_ME_FIREWORK_YELLOW)
        return true, string.format("AWAKENING SUCCESS! Your item has ascended to %s! (All bonuses preserved)", targetTierInfo.name)
    else
        -- Failure: add progress
        local newProgress = currentProgress + awakenConfig.failProgress
        Rarity.setItemProgress(item, newProgress)

        if hasProtectionStone then
            -- Protection used: no downgrade
            player:getPosition():sendMagicEffect(CONST_ME_POFF)
            return false, string.format("Awakening failed! The %s protected your item from downgrading. (+%d Progress, Total: %d/%d)",
                protMaterial.name, awakenConfig.failProgress, newProgress, awakenConfig.pityThreshold)
        else
            -- No protection: Downgrade tier, but KEEP progress
            local downgradeTier = tierInfo.downgradeTier or Rarity.TIERS.EPIC
            local downgradeInfo = Rarity.TIER_INFO[downgradeTier]

            Rarity.setItemTier(item, downgradeTier)
            -- Progress is preserved across downgrade!
            Rarity.setItemProgress(item, newProgress)

            player:getPosition():sendMagicEffect(CONST_ME_MORTAREA)
            return false, string.format("Awakening failed! Your item was downgraded to %s! (Your %d Progress was preserved)",
                downgradeInfo.name, newProgress)
        end
    end
end





-- Crafting: Allows players to craft an Awakening Protection Stone using high-tier essences and gold
function Rarity.craftProtectionStone(player)
    if not player or not player:isPlayer() then
        return false, "Invalid player."
    end

    local legEssence = Rarity.ESSENCE_ITEMS[Rarity.TIERS.LEGENDARY]
    local mythEssence = Rarity.ESSENCE_ITEMS[Rarity.TIERS.MYTHIC]
    local reqLeg = 10
    local reqMyth = 5
    local reqGold = 250000

    if player:getItemCount(legEssence.itemId) < reqLeg then
        return false, string.format("You need %d %s to craft a Protection Stone.", reqLeg, legEssence.name)
    end

    if player:getItemCount(mythEssence.itemId) < reqMyth then
        return false, string.format("You need %d %s to craft a Protection Stone.", reqMyth, mythEssence.name)
    end

    local currentMoney = player:getMoney() + player:getBankBalance()
    if currentMoney < reqGold then
        return false, string.format("You need %d gold to craft a Protection Stone.", reqGold)
    end

    -- Deduct costs
    player:removeItem(legEssence.itemId, reqLeg)
    player:removeItem(mythEssence.itemId, reqMyth)
    player:removeMoneyBank(reqGold)

    -- Reward Protection Stone
    local protMaterial = Rarity.PROTECTION_MATERIAL
    player:addItem(protMaterial.itemId, 1)

    player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
    return true, string.format("Crafting successful! You created 1x %s.", protMaterial.name)
end

-- Processes un-evaluated equipment inside a player's Reward Chest, applying Rarity rolls and notifying the player
function Rarity.processRewardChestForPlayer(player, bossScore, bossName, fromDeath)
    if not player or not player:isPlayer() then
        return {}
    end

    local rewardChest = player:getRewardChest()
    if not rewardChest then
        return {}
    end

    local items = rewardChest:getItems(true)
    if not items or #items == 0 then
        return {}
    end

    bossScore = bossScore or 5000
    local multiConfig = Rarity.LOOT_CONFIG.MULTIPLE_DROPS or {}
    local maxAllowed = multiConfig.MAX_RARITY_PER_BOSS or 2

    local rarityDroppedCount = 0
    local deliveredLootDescriptions = {}
    local highestTierRolled = Rarity.TIERS.COMMON

    for _, item in ipairs(items) do
        if Rarity.isEligible(item) then
            local evaluated = item:getCustomAttribute("RarityEvaluated")
            local currentTier = Rarity.getItemTier(item)

            if not evaluated and currentTier == Rarity.TIERS.COMMON then
                item:setCustomAttribute("RarityEvaluated", 1)

                if rarityDroppedCount < maxAllowed then
                    local rolledTier = Rarity.rollRarityTier and Rarity.rollRarityTier(bossScore, rarityDroppedCount, maxAllowed) or Rarity.TIERS.COMMON
                    if rolledTier > Rarity.TIERS.COMMON then
                        rarityDroppedCount = rarityDroppedCount + 1
                        Rarity.applyTierToItem(item, rolledTier, false)
                        if rolledTier > highestTierRolled then
                            highestTierRolled = rolledTier
                        end

                        local tierInfo = Rarity.TIER_INFO[rolledTier]
                        local tierName = tierInfo and tierInfo.name or "Rarity"
                        local rawName = item:getName() or "equipment"

                        local firstChar = tierName:sub(1, 1):lower()
                        local article = (firstChar == "a" or firstChar == "e" or firstChar == "i" or firstChar == "o" or firstChar == "u") and "an" or "a"

                        local notifyMsg
                        if fromDeath then
                            local bossStr = bossName and (" from " .. bossName) or ""
                            notifyMsg = string.format("[Reward Boss] Congratulations! You obtained %s [%s] %s%s! Check your Reward Chest to claim it.", article, tierName, rawName, bossStr)
                        else
                            notifyMsg = string.format("[Reward Chest] You discovered %s [%s] %s in your reward container!", article, tierName, rawName)
                        end

                        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, notifyMsg)
                        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, notifyMsg)

                        local lootEntry = string.format("%s [%s] %s (Reward Chest)", article, tierName, rawName)
                        table.insert(deliveredLootDescriptions, lootEntry)
                    end
                end
            end
        end
    end

    if highestTierRolled > Rarity.TIERS.COMMON then
        local pos = player:getPosition()
        if pos then
            pos:sendMagicEffect(CONST_ME_FIREWORK_YELLOW)
        end
    end

    return deliveredLootDescriptions
end
