-- Handlers TCP optimisés pour éviter les recherches répétitives
-- À intégrer dans main.lua pour remplacer la longue section TCP

local TCPHandlers = {}

-- Cache local pour éviter les recherches répétitives dans une même session
local handlerCache = {}

-- Fonction utilitaire pour obtenir/mettre en cache un joueur
local function getPlayerFromTcp(clientid)
    if handlerCache[clientid] then
        return handlerCache[clientid]
    end
    
    local playerId = _G.Server:getClientByTcp(clientid)
    if playerId then
        handlerCache[clientid] = playerId
        -- Nettoyer le cache après 10 secondes pour éviter l'accumulation
        love.timer.schedule(10, function() handlerCache[clientid] = nil end)
    end
    
    return playerId
end

-- Fonction utilitaire pour mettre à jour lastSeen
local function updateLastSeen(playerId)
    if playerId and _G.Server.Clients[playerId] then
        _G.Server.Clients[playerId].lastSeen = love.timer.getTime()
    end
end

-- Handler pour les demandes de recrutement
function TCPHandlers.handleRecruitmentRequest(packet, clientid)
    local playerId = getPlayerFromTcp(clientid)
    if not playerId then
        _G.Server.Tcp:send(_G.bitser.dumps({
            id = "recruitment_result",
            data = {
                success = false,
                reason = "player_not_found",
                message = "Joueur non trouvé!"
            }
        }), clientid)
        return
    end
    
    updateLastSeen(playerId)
    
    local villagerId = packet.data.villagerId
    local result = _G.RealmWorld:handleRecruitmentRequest(playerId, villagerId)
    
    _G.Server.Tcp:send(_G.bitser.dumps({
        id = "recruitment_result",
        data = result
    }), clientid)
    
    if result.success then
        print("[RECRUIT] ✅", playerId, "recruté", villagerId, "pour", result.goldSpent, "or")
    end
end

-- Handler pour les demandes de menu contextuel
function TCPHandlers.handleMenuRequest(packet, clientid)
    local playerId = getPlayerFromTcp(clientid)
    if not playerId then
        _G.Server.Tcp:send(_G.bitser.dumps({
            id = "villager_menu_data",
            data = {
                success = false,
                reason = "player_not_found",
                message = "Joueur non trouvé!"
            }
        }), clientid)
        return
    end
    
    updateLastSeen(playerId)
    
    local villagerId = packet.data.villagerId
    local result = _G.RealmWorld:handleMenuRequest(playerId, villagerId)
    
    _G.Server.Tcp:send(_G.bitser.dumps({
        id = "villager_menu_data",
        data = result
    }), clientid)
end

-- Handler pour l'assignation de tâches
function TCPHandlers.handleTaskAssignment(packet, clientid)
    local playerId = getPlayerFromTcp(clientid)
    if not playerId then
        _G.Server.Tcp:send(_G.bitser.dumps({
            id = "task_assignment_result",
            data = {
                success = false,
                reason = "player_not_found",
                message = "Joueur non trouvé!"
            }
        }), clientid)
        return
    end
    
    updateLastSeen(playerId)
    
    local villagerId = packet.data.villagerId
    local taskId = packet.data.taskId
    local result = _G.RealmWorld:handleTaskAssignment(playerId, villagerId, taskId)
    
    _G.Server.Tcp:send(_G.bitser.dumps({
        id = "task_assignment_result",
        data = result
    }), clientid)
end

-- Handler pour la fermeture de menu
function TCPHandlers.handleMenuClose(packet, clientid)
    local playerId = getPlayerFromTcp(clientid)
    if not playerId then
        return
    end
    
    updateLastSeen(playerId)
    
    local villagerId = packet.data.villagerId
    local result = _G.RealmWorld:closeVillagerMenu(playerId, villagerId)
end

-- Table de dispatch optimisée
TCPHandlers.dispatch = {
    ["player_recruit_villager"] = TCPHandlers.handleRecruitmentRequest,
    ["player_open_villager_menu"] = TCPHandlers.handleMenuRequest,
    ["player_assign_task"] = TCPHandlers.handleTaskAssignment,
    ["player_close_villager_menu"] = TCPHandlers.handleMenuClose
}

-- Fonction principale de traitement optimisée
function TCPHandlers.processMessage(packet, clientid)
    local handler = TCPHandlers.dispatch[packet.id]
    if handler then
        handler(packet, clientid)
        return true
    end
    return false
end

return TCPHandlers 
