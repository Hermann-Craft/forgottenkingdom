-- Gestionnaire centralisé des mises à jour d'entités pour optimiser le réseau
local EntityUpdateManager = require(_G.libDir .. "middleclass")("EntityUpdateManager")

function EntityUpdateManager:initialize()
    -- File d'attente des entités à mettre à jour
    self.updateQueue = {}
    
    -- Groupement par zone pour optimiser l'envoi
    self.zones = {}
    self.zoneSize = 200  -- Taille des zones en pixels
    
    -- Statistiques
    self.stats = {
        totalUpdates = 0,
        batchedUpdates = 0,
        playersNotified = 0,
        lastResetTime = love.timer.getTime()
    }
    
    -- Configuration
    self.batchInterval = 0.033  -- Envoyer les batchs toutes les 33ms (30 FPS)
    self.lastBatchTime = 0
    self.maxBatchSize = 20  -- Maximum 20 entités par batch
    
    print("[ENTITY-UPDATE-MANAGER] Gestionnaire initialisé")
    print("  - Intervalle batch:", self.batchInterval, "s")
    print("  - Taille max batch:", self.maxBatchSize)
    print("  - Taille zone:", self.zoneSize, "px")
end

-- Ajouter une entité à la file d'attente de mise à jour
function EntityUpdateManager:queueUpdate(entity, priority)
    priority = priority or "normal"
    
    local updateItem = {
        entity = entity,
        priority = priority,
        timestamp = love.timer.getTime(),
        zone = self:getEntityZone(entity)
    }
    
    table.insert(self.updateQueue, updateItem)
    self.stats.totalUpdates = self.stats.totalUpdates + 1
end

-- Calculer la zone d'une entité
function EntityUpdateManager:getEntityZone(entity)
    local position = entity:getComponent("Position")
    if not position or not position.position then
        return "global"  -- Zone globale pour les entités sans position
    end
    
    local zoneX = math.floor(position.position.x / self.zoneSize)
    local zoneY = math.floor(position.position.y / self.zoneSize)
    return string.format("%d_%d", zoneX, zoneY)
end

-- Traiter la file d'attente et envoyer les batchs
function EntityUpdateManager:processBatch(dt)
    local currentTime = love.timer.getTime()
    
    -- Vérifier s'il est temps d'envoyer un batch
    if (currentTime - self.lastBatchTime) < self.batchInterval then
        return
    end
    
    if #self.updateQueue == 0 then
        return
    end
    
    -- Grouper les mises à jour par zone
    local zoneGroups = {}
    local processedCount = 0
    
    for i = #self.updateQueue, 1, -1 do
        if processedCount >= self.maxBatchSize then
            break
        end
        
        local updateItem = table.remove(self.updateQueue, i)
        local zone = updateItem.zone
        
        if not zoneGroups[zone] then
            zoneGroups[zone] = {}
        end
        
        table.insert(zoneGroups[zone], updateItem)
        processedCount = processedCount + 1
    end
    
    -- Envoyer les batchs par zone
    for zone, updates in pairs(zoneGroups) do
        self:sendZoneBatch(zone, updates)
    end
    
    self.lastBatchTime = currentTime
    self.stats.batchedUpdates = self.stats.batchedUpdates + 1
end

-- Envoyer un batch d'entités pour une zone spécifique
function EntityUpdateManager:sendZoneBatch(zone, updates)
    if #updates == 0 then return end
    
    -- Créer le paquet batch
    local batchData = {
        id = "entity_batch_update",
        zone = zone,
        timestamp = love.timer.getTime(),
        entities = {}
    }
    
    -- Compiler les données des entités
    for _, updateItem in ipairs(updates) do
        local entityData = updateItem.entity:createDeltaUpdate()
        if entityData then
            table.insert(batchData.entities, entityData)
        end
    end
    
    if #batchData.entities == 0 then return end
    
    -- Déterminer les clients à notifier selon la zone
    local clientsToNotify = self:getClientsForZone(zone, updates)
    
    -- Envoyer le batch aux clients concernés
    local serializedBatch = _G.bitser.dumps(batchData)
    for _, clientData in ipairs(clientsToNotify) do
        if clientData.udp then
            _G.Server.Udp:send(serializedBatch, clientData.udp)
            self.stats.playersNotified = self.stats.playersNotified + 1
        end
    end
end

-- Obtenir les clients qui doivent être notifiés pour une zone
function EntityUpdateManager:getClientsForZone(zone, updates)
    local clientsToNotify = {}
    local notificationRadius = 400
    
    -- Pour la zone globale, notifier tous les clients
    if zone == "global" then
        for playerId, clientData in pairs(_G.Server.Clients or {}) do
            if clientData.udp then
                table.insert(clientsToNotify, clientData)
            end
        end
        return clientsToNotify
    end
    
    -- Pour les zones spatiales, calculer la proximité
    local zoneCenter = self:getZoneCenter(zone)
    
    for playerId, clientData in pairs(_G.Server.Clients or {}) do
        if clientData.udp then
            local player = _G.RealmWorld:getEntityById(playerId)
            if player then
                local playerPosition = player:getComponent("Position")
                if playerPosition and playerPosition.position then
                    local distance = math.sqrt(
                        (playerPosition.position.x - zoneCenter.x)^2 + 
                        (playerPosition.position.y - zoneCenter.y)^2
                    )
                    
                    if distance <= notificationRadius then
                        table.insert(clientsToNotify, clientData)
                    end
                end
            end
        end
    end
    
    return clientsToNotify
end

-- Calculer le centre d'une zone
function EntityUpdateManager:getZoneCenter(zone)
    local zoneX, zoneY = zone:match("(%d+)_(%d+)")
    if zoneX and zoneY then
        return {
            x = (tonumber(zoneX) + 0.5) * self.zoneSize,
            y = (tonumber(zoneY) + 0.5) * self.zoneSize
        }
    end
    return {x = 0, y = 0}
end

-- Obtenir les statistiques
function EntityUpdateManager:getStats()
    local currentTime = love.timer.getTime()
    local elapsedTime = currentTime - self.stats.lastResetTime
    
    local stats = {
        totalUpdates = self.stats.totalUpdates,
        batchedUpdates = self.stats.batchedUpdates,
        playersNotified = self.stats.playersNotified,
        queueSize = #self.updateQueue,
        updatesPerSecond = self.stats.totalUpdates / elapsedTime,
        batchesPerSecond = self.stats.batchedUpdates / elapsedTime,
        averageBatchSize = self.stats.totalUpdates / math.max(1, self.stats.batchedUpdates)
    }
    
    return stats
end

-- Réinitialiser les statistiques
function EntityUpdateManager:resetStats()
    self.stats = {
        totalUpdates = 0,
        batchedUpdates = 0,
        playersNotified = 0,
        lastResetTime = love.timer.getTime()
    }
end

-- Forcer le traitement de la file d'attente
function EntityUpdateManager:flush()
    while #self.updateQueue > 0 do
        self:processBatch(0)
    end
end

return EntityUpdateManager 
