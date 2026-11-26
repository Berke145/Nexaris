--[[
    Nexaris Rarity System - Player Stats & Attribute Synchronization
    Prevents duplicate application (stat leaking / duping) via memory snapshots and ConditionAttributes.
]]

Rarity = Rarity or {}

-- Memory cache: [guid] = { [slot] = { [bonusId] = value, ... } }
Rarity.activeBonuses = Rarity.activeBonuses or {}

local RARITY_CONDITION_BASE_SUBID = 1000

-- Completely strips any active bonuses and conditions tracked for a specific slot
function Rarity.stripSlotBonuses(player, slot)
    if not player or not slot then
        return
    end

    local guid = player:getGuid()
    local trackedSlotBonuses = Rarity.activeBonuses[guid] and Rarity.activeBonuses[guid][slot]

    -- Remove skill condition for this slot if applied
    player:removeCondition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT, RARITY_CONDITION_BASE_SUBID + slot)

    if trackedSlotBonuses then
        for bonusId, val in pairs(trackedSlotBonuses) do
            if bonusId == "max_hp" then
                local currentMax = player:getMaxHealth()
                local newMax = math.max(1, currentMax - val)
                player:setMaxHealth(newMax)
                player:setHealth(math.min(player:getHealth(), newMax))
            elseif bonusId == "max_mp" then
                local currentMax = player:getMaxMana()
                local newMax = math.max(0, currentMax - val)
                player:setMaxMana(newMax)
                player:setMana(math.min(player:getMana(), newMax))
            elseif bonusId == "bonus_speed" then
                player:changeSpeed(-val)
            elseif bonusId == "crit_chance" then
                player:addSpecialSkill(SPECIALSKILL_CRITICALHITCHANCE, -val * 100)
                player:addSpecialSkill(SPECIALSKILL_CRITICALHITAMOUNT, -6000)
            elseif bonusId == "life_leech" then
                player:addSpecialSkill(SPECIALSKILL_LIFELEECHCHANCE, -10000)
                player:addSpecialSkill(SPECIALSKILL_LIFELEECHAMOUNT, -val * 100)
            elseif bonusId == "mana_leech" then
                player:addSpecialSkill(SPECIALSKILL_MANALEECHCHANCE, -10000)
                player:addSpecialSkill(SPECIALSKILL_MANALEECHAMOUNT, -val * 100)
            end
        end
        Rarity.activeBonuses[guid][slot] = nil
    end
end

-- Applies bonuses for an item equipped in a specific slot
function Rarity.applySlotBonuses(player, item, slot)
    if not player or not item or not slot then
        return
    end

    -- Strip existing slot bonuses first to prevent double-stacking
    Rarity.stripSlotBonuses(player, slot)

    if not Rarity.isEligible(item) then
        return
    end

    local bonuses = Rarity.getBonuses(item)
    if not bonuses or next(bonuses) == nil then
        return
    end

    local guid = player:getGuid()
    Rarity.activeBonuses[guid] = Rarity.activeBonuses[guid] or {}
    Rarity.activeBonuses[guid][slot] = {}

    local skillMelee = 0
    local skillDist = 0
    local skillMagic = 0
    local skillShield = 0
    local hasSkillCondition = false

    for _, b in pairs(bonuses) do
        if b.id and b.val and b.val > 0 then
            local val = b.val
            Rarity.activeBonuses[guid][slot][b.id] = (Rarity.activeBonuses[guid][slot][b.id] or 0) + val

            if b.id == "skill_melee" then
                skillMelee = skillMelee + val
                hasSkillCondition = true
            elseif b.id == "skill_dist" then
                skillDist = skillDist + val
                hasSkillCondition = true
            elseif b.id == "skill_magic" then
                skillMagic = skillMagic + val
                hasSkillCondition = true
            elseif b.id == "skill_shield" then
                skillShield = skillShield + val
                hasSkillCondition = true
            elseif b.id == "max_hp" then
                local currentMax = player:getMaxHealth()
                player:setMaxHealth(currentMax + val)
                player:addHealth(val)
            elseif b.id == "max_mp" then
                local currentMax = player:getMaxMana()
                player:setMaxMana(currentMax + val)
                player:addMana(val)
            elseif b.id == "bonus_speed" then
                player:changeSpeed(val)
            elseif b.id == "crit_chance" then
                player:addSpecialSkill(SPECIALSKILL_CRITICALHITCHANCE, val * 100)
                player:addSpecialSkill(SPECIALSKILL_CRITICALHITAMOUNT, 6000)
            elseif b.id == "life_leech" then
                player:addSpecialSkill(SPECIALSKILL_LIFELEECHCHANCE, 10000)
                player:addSpecialSkill(SPECIALSKILL_LIFELEECHAMOUNT, val * 100)
            elseif b.id == "mana_leech" then
                player:addSpecialSkill(SPECIALSKILL_MANALEECHCHANCE, 10000)
                player:addSpecialSkill(SPECIALSKILL_MANALEECHAMOUNT, val * 100)
            end
        end
    end

    -- Create and apply skill condition if applicable
    if hasSkillCondition then
        local condition = Condition(CONDITION_ATTRIBUTES, CONDITIONID_DEFAULT)
        condition:setParameter(CONDITION_PARAM_TICKS, -1)
        condition:setParameter(CONDITION_PARAM_SUBID, RARITY_CONDITION_BASE_SUBID + slot)

        if skillMelee > 0 then
            condition:setParameter(CONDITION_PARAM_SKILL_MELEE, skillMelee)
        end
        if skillDist > 0 then
            condition:setParameter(CONDITION_PARAM_SKILL_DISTANCE, skillDist)
        end
        if skillMagic > 0 then
            condition:setParameter(CONDITION_PARAM_STAT_MAGICPOINTS, skillMagic)
        end
        if skillShield > 0 then
            condition:setParameter(CONDITION_PARAM_SKILL_SHIELD, skillShield)
        end

        player:addCondition(condition)
    end
end

-- Returns aggregated bonus value across all equipped slots
function Rarity.getTotalBonus(player, bonusId)
    if not player or not bonusId then
        return 0
    end
    local guid = player:getGuid()
    local playerBonuses = Rarity.activeBonuses[guid]
    if not playerBonuses then
        return 0
    end
    local sum = 0
    for slot, slotBonuses in pairs(playerBonuses) do
        if slotBonuses[bonusId] then
            sum = sum + slotBonuses[bonusId]
        end
    end
    return sum
end

-- Full resynchronization (called on login or full gear refresh)
function Rarity.recalculatePlayerStats(player)
    if not player then
        return
    end

    local guid = player:getGuid()

    -- Strip all currently tracked bonuses and conditions
    for slot = CONST_SLOT_HEAD, CONST_SLOT_AMMO do
        Rarity.stripSlotBonuses(player, slot)
    end
    Rarity.activeBonuses[guid] = {}

    -- Re-evaluate all equipment slots
    for slot = CONST_SLOT_HEAD, CONST_SLOT_AMMO do
        local item = player:getSlotItem(slot)
        if item then
            Rarity.applySlotBonuses(player, item, slot)
        end
    end
end

-- Cleanup when player logs out
function Rarity.cleanupPlayer(player)
    if not player then
        return
    end

    local guid = player:getGuid()
    for slot = CONST_SLOT_HEAD, CONST_SLOT_AMMO do
        Rarity.stripSlotBonuses(player, slot)
    end
    Rarity.activeBonuses[guid] = nil
end
