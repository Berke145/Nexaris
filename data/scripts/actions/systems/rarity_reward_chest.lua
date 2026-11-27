local ITEM_REWARD_CHEST = 19250
local ITEM_REWARD_CONTAINER = 19202

local rewardChestAction = Action()

function rewardChestAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
    if not player or not player:isPlayer() then
        return false
    end

    if Rarity and Rarity.processRewardChestForPlayer then
        Rarity.processRewardChestForPlayer(player, 5000, nil, false)
    end

    -- Return false so C++ handles standard container opening without interference
    return false
end

rewardChestAction:id(ITEM_REWARD_CHEST, ITEM_REWARD_CONTAINER)
rewardChestAction:register()
