--[[
    Nexaris Rarity System - Loot Drop Handler
    Calculates monster PowerScore, enforces tier gating, and assigns rarity to eligible corpse loot.
]]

local event = Event()

-- Calculates monster PowerScore based on level, max HP, boss status, and location
local function calculateMonsterPowerScore(monster)
    if not monster or not monster:isMonster() then
        return 0
    end

    local mType = monster:getType()
    if not mType then
        return 0
    end

    local mLevel = monster.getLevel and monster:getLevel() or 1
    local maxHp = mType:getMaxHealth() or 100

    -- Level & HP base score
    local score = (mLevel * 10) + math.floor(maxHp / 100)

    -- Boss status evaluation
    local isBoss = false
    if mType.isBoss and mType:isBoss() then
        isBoss = true
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

    return score
end

-- Determines the maximum tier allowed for a given PowerScore (Tier Gating)
local function getTierCapForScore(score)
    for _, capInfo in ipairs(Rarity.LOOT_CONFIG.CAPS) do
        if score <= capInfo.maxScore then
            return capInfo.maxTier
        end
    end
    return Rarity.TIERS.MYTHIC
end

-- Rolls a rarity tier according to PowerScore and gating caps
local function rollRarityTier(score)
    if score < Rarity.LOOT_CONFIG.MIN_SCORE_FOR_RARITY then
        return Rarity.TIERS.COMMON
    end

    local capTier = getTierCapForScore(score)

    -- Roll from highest possible down to Uncommon
    for tier = capTier, Rarity.TIERS.UNCOMMON, -1 do
        local divider = Rarity.LOOT_CONFIG.TIER_CHANCE_DIVIDERS[tier]
        if divider then
            -- chance in percent = (score / divider)
            -- e.g. Score 3000 / 600 = 5% chance
            local chancePercent = math.min(50, score / divider)
            local roll = math.random(1, 10000) / 100
            if roll <= chancePercent then
                return tier
            end
        end
    end

    return Rarity.TIERS.COMMON
end

-- Visual notification for high tier drops
local function triggerDropEffect(corpse, highestTier)
    if not corpse or highestTier < Rarity.TIERS.RARE then
        return
    end

    local pos = corpse:getPosition()
    if not pos then
        return
    end

    if highestTier >= Rarity.TIERS.LEGENDARY then
        pos:sendMagicEffect(CONST_ME_FIREWORK_YELLOW)
    elseif highestTier >= Rarity.TIERS.EPIC then
        pos:sendMagicEffect(CONST_ME_PURPLEENERGY)
    else
        pos:sendMagicEffect(CONST_ME_MAGIC_GREEN)
    end
end

event.onDropLoot = function(self, corpse)
    if not corpse or not corpse:isContainer() then
        return
    end

    local score = calculateMonsterPowerScore(self)
    if score < Rarity.LOOT_CONFIG.MIN_SCORE_FOR_RARITY then
        return
    end

    local corpseContainer = corpse:getContainer()
    if not corpseContainer then
        return
    end

    local items = corpseContainer:getItems(true)
    local highestTierRolled = Rarity.TIERS.COMMON

    for _, item in ipairs(items) do
        if Rarity.isEligible(item) and Rarity.getItemTier(item) == Rarity.TIERS.COMMON then
            local rolledTier = rollRarityTier(score)
            if rolledTier > Rarity.TIERS.COMMON then
                Rarity.applyTierToItem(item, rolledTier, false)
                if rolledTier > highestTierRolled then
                    highestTierRolled = rolledTier
                end
            end
        end
    end

    -- Boss drop: Chance to drop Awakening Protection Stone from formidable bosses
    if score >= 4000 then
        -- 5% chance on high tier boss
        if math.random(1, 100) <= 5 then
            corpseContainer:addItem(Rarity.PROTECTION_MATERIAL.itemId, 1)
            pos = corpse:getPosition()
            if pos then
                pos:sendMagicEffect(CONST_ME_MAGIC_BLUE)
            end
        end
    end

    if highestTierRolled >= Rarity.TIERS.RARE then
        triggerDropEffect(corpse, highestTierRolled)
    end
end

event:register()
