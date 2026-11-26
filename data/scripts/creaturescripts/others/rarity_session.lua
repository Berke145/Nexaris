--[[
    Nexaris Rarity System - Player Session Manager
    Handles clean stat calculation on login and memory cleanup on logout.
]]

local rarityLogin = CreatureEvent("RarityLogin")

function rarityLogin.onLogin(player)
    player:registerEvent("RarityLogout")
    Rarity.recalculatePlayerStats(player)
    if player.wheelSendSkillStats then
        player:wheelSendSkillStats(true)
    end
    player:sendStats()

    local playerId = player:getId()
    addEvent(function(pid)
        local p = Player(pid)
        if p and p.wheelSendSkillStats then
            p:wheelSendSkillStats(true)
            p:sendStats()
        end
    end, 300, playerId)

    return true
end

rarityLogin:register()

local rarityLogout = CreatureEvent("RarityLogout")

function rarityLogout.onLogout(player)
    Rarity.cleanupPlayer(player)
    return true
end

rarityLogout:register()
