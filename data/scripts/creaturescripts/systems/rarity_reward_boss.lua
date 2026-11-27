local rewardBossDeath = CreatureEvent("RarityRewardBossDeath")

function rewardBossDeath.onDeath(creature, corpse, lastHitCreature, mostDamageCreature, lastHitUnjustified, mostDamageUnjustified)
    if not creature or not creature:isMonster() then
        return true
    end

    local mType = creature:getType()
    if not mType or not (mType.isRewardBoss and mType:isRewardBoss()) then
        return true
    end

    local score = Rarity.calculateMonsterPowerScore and Rarity.calculateMonsterPowerScore(creature) or 5000
    if score < 4000 then
        score = score + 3000
    end
    local bossName = creature:getName()

    local evaluatedPlayers = {}
    local damageMap = creature:getDamageMap()
    if damageMap then
        for playerId, _ in pairs(damageMap) do
            evaluatedPlayers[playerId] = true
        end
    end

    if mostDamageCreature and mostDamageCreature:isPlayer() then
        evaluatedPlayers[mostDamageCreature:getId()] = true
    end
    if lastHitCreature and lastHitCreature:isPlayer() then
        evaluatedPlayers[lastHitCreature:getId()] = true
    end

    local pos = creature:getPosition()
    if pos then
        local spectators = Game.getSpectators(pos, false, true, 15, 15, 15, 15)
        for _, spec in ipairs(spectators) do
            if spec:isPlayer() then
                evaluatedPlayers[spec:getId()] = true
            end
        end
    end

    -- C++ generates reward items inside Monster::death which executes immediately after onDeath returns.
    -- Using addEvent(..., 150) ensures the reward container is already populated in player:getRewardChest().
    for pId, _ in pairs(evaluatedPlayers) do
        addEvent(function(targetId, targetScore, targetBossName)
            local p = Player(targetId)
            if p then
                Rarity.processRewardChestForPlayer(p, targetScore, targetBossName, true)
            end
        end, 150, pId, score, bossName)
    end

    return true
end

rewardBossDeath:register()

-- Register the event on all existing Reward Boss MonsterTypes
for _, mType in ipairs(Game.getMonsterTypes()) do
    if mType.isRewardBoss and mType:isRewardBoss() then
        mType:registerEvent("RarityRewardBossDeath")
    end
end

-- Also register on any future spawns via EventCallback
local ec = EventCallback

function ec.onSpawn(monster, position, startup, artificial)
    if not monster or not monster:isMonster() then
        return true
    end

    local mType = monster:getType()
    if mType and (mType.isRewardBoss and mType:isRewardBoss()) then
        monster:registerEvent("RarityRewardBossDeath")
    end

    return true
end

ec:register()
