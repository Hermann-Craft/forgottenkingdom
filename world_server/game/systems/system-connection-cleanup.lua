local ConnectionCleanupSystem = require(_G.libDir .. "middleclass")("ConnectionCleanupSystem")

function ConnectionCleanupSystem:initialize(world)
    self.world = world
    self.cleanupInterval = 30 -- Vérifier toutes les 30 secondes
    self.cleanupTimer = 0
    self.timeoutDuration = 60 -- Timeout après 60 secondes d'inactivité
    self.debugMode = false
    
    print("[CONNECTION-CLEANUP] Système de nettoyage initialisé")
    print("[CONNECTION-CLEANUP] Intervalle de vérification:", self.cleanupInterval, "secondes")
    print("[CONNECTION-CLEANUP] Timeout d'inactivité:", self.timeoutDuration, "secondes")
end

function ConnectionCleanupSystem:update(dt)
    self.cleanupTimer = self.cleanupTimer + dt
    
    if self.cleanupTimer >= self.cleanupInterval then
        self:performCleanup()
        self.cleanupTimer = 0
    end
end

function ConnectionCleanupSystem:performCleanup()
    if self.debugMode then
        print("[CONNECTION-CLEANUP] Début du nettoyage automatique")
    end
    
    local currentTime = love.timer.getTime()
    local playersToCleanup = {}
    
    -- Vérifier chaque client connecté
    for playerId, clientData in pairs(_G.Server.Clients or {}) do
        local shouldCleanup = false
        local reason = ""
        
        -- Vérifier si les connexions TCP/UDP sont encore valides
        if not clientData.tcp and not clientData.udp then
            shouldCleanup = true
            reason = "no_connection"
        elseif clientData.lastSeen and (currentTime - clientData.lastSeen) > self.timeoutDuration then
            shouldCleanup = true
            reason = "timeout"
        elseif not clientData.lastSeen then
            -- Joueur sans timestamp, probablement ancien système
            shouldCleanup = true
            reason = "no_timestamp"
        end
        
        if shouldCleanup then
            table.insert(playersToCleanup, {
                playerId = playerId,
                reason = reason,
                inactiveTime = clientData.lastSeen and (currentTime - clientData.lastSeen) or "unknown"
            })
        end
    end
    
    -- Nettoyer les joueurs identifiés
    for _, playerInfo in ipairs(playersToCleanup) do
        if self.debugMode then
            print("[CONNECTION-CLEANUP] Nettoyage du joueur", playerInfo.playerId, 
                  "- Raison:", playerInfo.reason, 
                  "- Inactif depuis:", playerInfo.inactiveTime, "secondes")
        end
        
        _G.cleanupDisconnectedPlayer(playerInfo.playerId, "auto_cleanup_" .. playerInfo.reason)
    end
    
    -- Statistiques de nettoyage
    if #playersToCleanup > 0 then
        print("[CONNECTION-CLEANUP] Nettoyage terminé -", #playersToCleanup, "joueur(s) supprimé(s)")
    elseif self.debugMode then
        print("[CONNECTION-CLEANUP] Nettoyage terminé - Aucun joueur à nettoyer")
    end
    
    -- Afficher les statistiques des connexions actives
    local activeConnections = 0
    for playerId, clientData in pairs(_G.Server.Clients or {}) do
        activeConnections = activeConnections + 1
    end
    
    if self.debugMode then
        print("[CONNECTION-CLEANUP] Connexions actives:", activeConnections)
    end
end

function ConnectionCleanupSystem:setDebugMode(enabled)
    self.debugMode = enabled
    print("[CONNECTION-CLEANUP] Mode debug:", enabled and "ACTIVÉ" or "DÉSACTIVÉ")
end

function ConnectionCleanupSystem:forceCleanup()
    print("[CONNECTION-CLEANUP] Nettoyage forcé demandé")
    self:performCleanup()
end

function ConnectionCleanupSystem:getConnectionStats()
    local stats = {
        totalClients = 0,
        tcpConnections = 0,
        udpConnections = 0,
        completeConnections = 0,
        partialConnections = 0,
        timeouts = 0
    }
    
    local currentTime = love.timer.getTime()
    
    for playerId, clientData in pairs(_G.Server.Clients or {}) do
        stats.totalClients = stats.totalClients + 1
        
        if clientData.tcp then
            stats.tcpConnections = stats.tcpConnections + 1
        end
        
        if clientData.udp then
            stats.udpConnections = stats.udpConnections + 1
        end
        
        if clientData.tcp and clientData.udp then
            stats.completeConnections = stats.completeConnections + 1
        elseif clientData.tcp or clientData.udp then
            stats.partialConnections = stats.partialConnections + 1
        end
        
        if clientData.lastSeen and (currentTime - clientData.lastSeen) > self.timeoutDuration then
            stats.timeouts = stats.timeouts + 1
        end
    end
    
    return stats
end

return ConnectionCleanupSystem 
