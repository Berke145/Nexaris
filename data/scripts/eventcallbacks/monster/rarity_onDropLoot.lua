--[[
    Nexaris Rarity System - Loot Drop Handler
    Calculates monster PowerScore, enforces tier gating, and assigns rarity to eligible corpse loot.
]]

-- Calculates monster PowerScore based on level, max HP, boss status, and location
local function calculateMonsterPowerScore(monster)
    if not monster or not monster:isMonster() then
        return 0
    end

    local maxHp = monster:getMaxHealth() or 100

    local mLevel = 1
    if monster.getLevel then
        mLevel = monster:getLevel() or 1
    end

    -- Base score is monster's max HP + (level * 10)
    local score = maxHp + (mLevel * 10)

    local mType = monster:getType()
    if mType then
        -- Boss / Reward Boss status evaluation
        local isBoss = (mType.isBoss and mType:isBoss()) or (mType.isRewardBoss and mType:isRewardBoss())
        if isBoss then
            score = score + Rarity.LOOT_CONFIG.BOSS_WEIGHTS.DEFAULT
        end

        local raceId = mType.raceId and mType:raceId() or 0
        if CustomBosstiary and CustomBosstiary.isBoostedBoss and CustomBosstiary.isBoostedBoss(raceId) then
            score = score + Rarity.LOOT_CONFIG.BOSS_WEIGHTS.BOOSTED_BOSS
        end

        -- Boosted creature check
        local boostedCreature = Game.getBoostedCreature and Game.getBoostedCreature()
        if boostedCreature and boostedCreature:lower() == mType:getName():lower() then
            score = score + 500
        end
    end

    return score
end
Rarity.calculateMonsterPowerScore = calculateMonsterPowerScore

-- Determines the maximum tier allowed for a given PowerScore (Tier Gating)
local function getTierCapForScore(score)
    for _, capInfo in ipairs(Rarity.LOOT_CONFIG.CAPS) do
        if score <= capInfo.maxScore then
            return capInfo.maxTier
        end
    end
    return Rarity.TIERS.MYTHIC
end
Rarity.getTierCapForScore = getTierCapForScore

-- Rolls a rarity tier according to PowerScore, gating caps, and diminishing returns
local function rollRarityTier(score, rolledSoFar, maxAllowed)
    rolledSoFar = rolledSoFar or 0
    maxAllowed = maxAllowed or 1

    -- If already reached the hard cap for this monster/boss, no further rarity rolls allowed
    if rolledSoFar >= maxAllowed then
        return Rarity.TIERS.COMMON
    end

    if score < Rarity.LOOT_CONFIG.MIN_SCORE_FOR_RARITY then
        return Rarity.TIERS.COMMON
    end

    local capTier = getTierCapForScore(score)

    if Rarity.LOOT_CONFIG.FORCE_DROP_TEST then
        return math.random(Rarity.TIERS.UNCOMMON, capTier)
    end

    local multiplier = Rarity.LOOT_CONFIG.CHANCE_MULTIPLIER or 1.0

    -- Diminishing returns penalty for subsequent rarity items from the same monster
    if rolledSoFar > 0 then
        local dimConfig = Rarity.LOOT_CONFIG.MULTIPLE_DROPS
        local dimMult = dimConfig and dimConfig.SUBSEQUENT_CHANCE_MULTIPLIER or 0.10
        multiplier = multiplier * (dimMult ^ rolledSoFar)
    end

    -- Roll from highest possible down to Uncommon
    for tier = capTier, Rarity.TIERS.UNCOMMON, -1 do
        local divider = Rarity.LOOT_CONFIG.TIER_CHANCE_DIVIDERS[tier]
        if divider then
            -- chance in percent = (score / divider) * multiplier
            local chancePercent = math.min(100, (score / divider) * multiplier)
            local roll = math.random(1, 10000) / 100
            if roll <= chancePercent then
                return tier
            end
        end
    end

    return Rarity.TIERS.COMMON
end
Rarity.rollRarityTier = rollRarityTier

-- Visual notification & animated text for rarity drops
local function triggerDropEffect(corpse, highestTier)
    if not corpse or highestTier <= Rarity.TIERS.COMMON then
        return
    end

    local pos = corpse:getPosition()
    if not pos then
        return
    end

    local tierInfo = Rarity.TIER_INFO[highestTier]
    local tierName = tierInfo and tierInfo.name or "Rarity"

    local color = TEXTCOLOR_WHITE
    local effect = CONST_ME_MAGIC_GREEN

    if highestTier == Rarity.TIERS.UNCOMMON then
        color = TEXTCOLOR_LIGHTGREEN
        effect = CONST_ME_MAGIC_GREEN
    elseif highestTier == Rarity.TIERS.RARE then
        color = TEXTCOLOR_LIGHTBLUE
        effect = CONST_ME_MAGIC_BLUE
    elseif highestTier == Rarity.TIERS.EPIC then
        color = TEXTCOLOR_PURPLE
        effect = CONST_ME_PURPLEENERGY
    elseif highestTier == Rarity.TIERS.LEGENDARY then
        color = TEXTCOLOR_ORANGE
        effect = CONST_ME_FIREWORK_YELLOW
    elseif highestTier == Rarity.TIERS.MYTHIC then
        color = TEXTCOLOR_RED
        effect = CONST_ME_FIREWORK_RED
    elseif highestTier == Rarity.TIERS.ETERNAL then
        color = TEXTCOLOR_TEAL
        effect = CONST_ME_FIREWORK_BLUE
    end

    if Game.sendAnimatedText then
        Game.sendAnimatedText(tierName:upper() .. "!", pos, color)
    end
    pos:sendMagicEffect(effect)
end

-- Main function to process rarity loot on a monster's corpse
function Rarity.processCorpseLoot(monster, corpse, player)
    if not monster or not corpse or not corpse:isContainer() then
        return {}
    end

    local score = calculateMonsterPowerScore(monster)
    if score < Rarity.LOOT_CONFIG.MIN_SCORE_FOR_RARITY then
        return {}
    end

    local items = corpse:getItems(true)
    if not items or #items == 0 then
        return {}
    end

    local mType = monster:getType()
    local isBoss = mType and ((mType.isBoss and mType:isBoss()) or (mType.isRewardBoss and mType:isRewardBoss())) or false
    local multiConfig = Rarity.LOOT_CONFIG.MULTIPLE_DROPS or {}
    local maxAllowed = isBoss and (multiConfig.MAX_RARITY_PER_BOSS or 2) or (multiConfig.MAX_RARITY_PER_MONSTER or 1)

    local highestTierRolled = Rarity.TIERS.COMMON
    local deliveredLootDescriptions = {}
    local rarityDroppedCount = 0

    for _, item in ipairs(items) do
        if rarityDroppedCount >= maxAllowed then
            break
        end

        if Rarity.isEligible(item) and Rarity.getItemTier(item) == Rarity.TIERS.COMMON then
            local rolledTier = rollRarityTier(score, rarityDroppedCount, maxAllowed)
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

                local deliveredToInbox = false
                if player and player:isPlayer() then
                    local storeInbox = player:getStoreInbox()
                    if storeInbox then
                        local moved = item:moveTo(storeInbox)
                        if moved ~= true then
                            storeInbox:addItemEx(item, INDEX_WHEREEVER, FLAG_NOLIMIT)
                        end
                        deliveredToInbox = true
                    end

                    local monsterName = monster:getName()
                    local notifyMsg = string.format("[Rarity Drop] Congratulations! You obtained %s [%s] %s from %s! The item was delivered directly to your Store Inbox.", article, tierName, rawName, monsterName)

                    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, notifyMsg)
                    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, notifyMsg)
                end

                local lootEntry = string.format("%s [%s] %s%s", article, tierName, rawName, deliveredToInbox and " (Store Inbox)" or "")
                table.insert(deliveredLootDescriptions, lootEntry)
            end
        end
    end

    -- Boss drop: Chance to drop Awakening Protection Stone from formidable bosses
    if score >= 4000 then
        if math.random(1, 100) <= 5 then
            corpse:addItem(Rarity.PROTECTION_MATERIAL.itemId, 1)
            local pos = corpse:getPosition()
            if pos then
                pos:sendMagicEffect(CONST_ME_MAGIC_BLUE)
            end
        end
    end

    if highestTierRolled > Rarity.TIERS.COMMON then
        triggerDropEffect(corpse, highestTierRolled)
    end

    return deliveredLootDescriptions
end
