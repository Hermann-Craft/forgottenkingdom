local WorldServer = require(_G.libDir .. "middleclass")("WorldServer")
local World = require(_G.engineDir .. "world")
local Serializer = require(_G.libDir .. "serializer")

function WorldServer:initialize(characterName)
    self.currentCharacter = characterName
    self.tcp = require(_G.libDir .. "tcp_client"):new()
    self.udp = require(_G.libDir .. "udp_client"):new()
    self.world = nil
    
    self.uiManager = nil -- Sera assigné par la scene

    self.tcp.callbacks.recv = function (data)
        local packet = _G.bitser.loads(data)
        
        -- Vérifier que packet est bien une tableÉ
        if type(packet) ~= "table" then
            print("[WORLD-SERVER] Erreur de désérialisation TCP:", packet)
            return
        end
        
        print(packet.id)
        if packet.id == "world_load" then
            self.world = World:new(packet.world.width, packet.world.height, packet.world.entities)
        elseif packet.id == "join_world" then
            if packet.status == 200 then
                print("world found")
                self:disconnect()
                self:connect(packet.server.ip, packet.server.port, self.currentCharacter)
                print(packet.server.ip)
                print(packet.server.port)
            elseif packet.status == 404 then
                print("world not found")
            end
        elseif packet.id == "mining_result" then
            -- Résultat d'une tentative de mining
            if packet.data.success then
                print("[MINING] Récolte réussie! +", packet.data.goldHarvested, "or - Total:", packet.data.newWalletTotal .. "/100")
                
                -- Notification UI de succès
                if self.uiManager then
                    self.uiManager:onMiningSuccess(packet.data.goldHarvested)
                end
                
                -- Animation de récolte (optionnel)
                if self.world and self.world.addGoldAnimation then
                    self.world:addGoldAnimation(packet.data.goldHarvested)
                end
            else
                print("[MINING] Récolte échouée:", packet.data.message or packet.data.reason)
                
                -- Notification UI d'erreur
                if self.uiManager then
                    self.uiManager:onMiningError(packet.data.message or packet.data.reason)
                end
            end
        elseif packet.id == "mine_state_update" then
            -- Mise à jour de l'état d'une mine (pour tous les joueurs)
            if self.world then
                self.world:updateMineState(packet.data.mineId, packet.data)
            end
        elseif packet.id == "recruitment_result" then
            -- Résultat d'une tentative de recrutement
            if packet.data.success then
                print("[VILLAGER] Recrutement réussi! -", packet.data.goldSpent, "or →", packet.data.villagerName, "rejoint", packet.data.clanName)
                
                -- Notification UI de succès
                if self.uiManager then
                    self.uiManager:onRecruitmentSuccess(packet.data.villagerName, packet.data.goldSpent)
                end
            else
                print("[VILLAGER] Recrutement échoué:", packet.data.message or packet.data.reason)
                
                -- Notification UI d'erreur
                if self.uiManager then
                    self.uiManager:onRecruitmentError(packet.data.message or packet.data.reason)
                end
            end
        elseif packet.id == "villager_menu_data" then
            -- Données du menu contextuel d'un villageois
            if packet.data.success then
                print("[VILLAGER] Menu reçu pour:", packet.data.villagerName, "- Tâche actuelle:", packet.data.currentTask)
                
                -- Ouvrir l'interface du menu contextuel
                if self.uiManager then
                    self.uiManager:openVillagerMenu(packet.data)
                end
            else
                print("[VILLAGER] Erreur menu:", packet.data.message or packet.data.reason)
                
                -- Notification d'erreur
                if self.uiManager then
                    self.uiManager:onRecruitmentError(packet.data.message or packet.data.reason)
                end
            end
        elseif packet.id == "task_assignment_result" then
            -- Résultat d'une assignation de tâche
            if packet.data.success then
                print("[VILLAGER] Tâche assignée:", packet.data.oldTask, "→", packet.data.newTask)
                
                -- Notification de succès
                if self.uiManager then
                    self.uiManager:onTaskAssignmentSuccess(packet.data.newTask, packet.data.villagerName)
                end
            else
                print("[VILLAGER] Erreur assignation:", packet.data.message or packet.data.reason)
                
                -- Notification d'erreur
                if self.uiManager then
                    self.uiManager:onRecruitmentError(packet.data.message or packet.data.reason)
                end
            end
        end
    end

    self.udp.callbacks.recv = function (data)
        local packet = _G.bitser.loads(data)
        
        -- Vérifier que packet est bien une table
        if type(packet) ~= "table" then
            print("[WORLD-SERVER] Erreur de désérialisation UDP:", packet)
            return
        end
        
        if packet.id == "world_update" then
            if self.world ~= nil then
                self.world.entities = packet.worldData.entities
            end
        elseif packet.id == "entity_update" then
            if self.world ~= nil then
                self.world:updateEntity(packet.entityId, packet.entityData)
            end
        elseif packet.id == "entity_create" then
            if self.world ~= nil then
                self.world:addEntity(packet.entityData)
            end
        elseif packet.id == "entity_remove" then
            if self.world ~= nil then
                self.world:removeEntity(packet.entityId)
            end
        end
    end
end

function WorldServer:connect(ip, port)
    self.tcp:connect(ip, port)
    self.udp:connect(ip, port)
end

function WorldServer:disconnect()
    self.tcp:disconnect()
    self.udp:disconnect()
end

function WorldServer:update(dt)
    self.tcp:update(dt)
    self.udp:update(dt)

    if self.world ~= nil then
        self.world:update(dt)
    end

    local z = love.keyboard.isDown("z");
    local w = love.keyboard.isDown("w");
    local q = love.keyboard.isDown("q");
    local a = love.keyboard.isDown("a");
    local d = love.keyboard.isDown("d");
    local s = love.keyboard.isDown("s");
    local lshift = love.keyboard.isDown("lshift");

    if self.world ~= nil then

        if z or w then
            self.udp:send(_G.bitser.dumps({
                id = "player_move",
                cmd = "up"
            }))
        end

        if q or a then
            self.udp:send(_G.bitser.dumps({
                id = "player_move",
                cmd = "left"
            }))
        end

        if d then
            self.udp:send(_G.bitser.dumps({
                id = "player_move",
                cmd = "right"
            }))
        end

        if s then
            self.udp:send(_G.bitser.dumps({
                id = "player_move",
                cmd = "down"
            }))
        end

        local mouseIsDown = love.mouse.isDown(1)
        if mouseIsDown then
            local mx, my = self.world.camera:mousePosition()
            self.udp:send(_G.bitser.dumps({
                id = "player_shoot",
                data = { x = mx, y = my },
            }))
        end

        local mx, my = self.world.camera:mousePosition()
        self.udp:send(_G.bitser.dumps({
            id = "player_orientation",
            data = { x = mx, y = my },
        }))
    end
end

function WorldServer:draw(...)
    if self.world ~= nil then
        self.world:draw(...)
    end
end

-- === NOUVEAUX SYSTÈMES DE CALCUL DE PROXIMITÉ ===

function WorldServer:calculateNearbyMines()
    -- Calculer les mines proches en temps réel depuis world.entities
    local nearbyMines = {}
    
    if not self.world or not self.world.entities then
        return nearbyMines
    end
    
    -- Trouver le joueur actuel
    local playerEntity = nil
    for _, entity in ipairs(self.world.entities) do
        if entity.id == _G.user.email then
            playerEntity = entity
            break
        end
    end
    
    if not playerEntity or not playerEntity.components["Position"] then
        return nearbyMines
    end
    
    local playerPos = playerEntity.components["Position"].position
    local playerDim = playerEntity.components["Dimension"]
    
    -- Chercher les mines proches
    for _, entity in ipairs(self.world.entities) do
        local resources = entity.components["Resources"]
        local entityPos = entity.components["Position"]
        local entityDim = entity.components["Dimension"]
        
        -- Si c'est une mine d'or
        if resources and entityPos and entityDim and resources.goldAmount then
            -- Calculer la distance
            local distance = math.sqrt(
                (playerPos.x - entityPos.position.x)^2 + 
                (playerPos.y - entityPos.position.y)^2
            )
            
            -- Distance de proximité pour les mines : 100 pixels
            if distance <= 100 then
                nearbyMines[entity.id] = {
                    canMine = resources.goldAmount > 0 and resources.state ~= "respawning",
                    goldAmount = resources.goldAmount,
                    maxGold = resources.maxGold,
                    state = resources.state,
                    distance = distance
                }
            end
        end
    end
    
    return nearbyMines
end

function WorldServer:calculateNearbyVillagers()
    -- Calculer les villageois proches en temps réel depuis world.entities
    local nearbyVillagers = {}
    
    if not self.world or not self.world.entities then
        return nearbyVillagers
    end
    
    -- Trouver le joueur actuel
    local playerEntity = nil
    for _, entity in ipairs(self.world.entities) do
        if entity.id == _G.user.email then
            playerEntity = entity
            break
        end
    end
    
    if not playerEntity or not playerEntity.components["Position"] then
        return nearbyVillagers
    end
    
    local playerPos = playerEntity.components["Position"].position
    local playerClan = playerEntity.components["Clan"]
    local playerWallet = playerEntity.components["Wallet"]
    
    -- Chercher les villageois proches
    for _, entity in ipairs(self.world.entities) do
        local villager = entity.components["Villager"]
        local entityPos = entity.components["Position"]
        local entityDim = entity.components["Dimension"]
        local entityClan = entity.components["Clan"]
        local entityName = entity.components["Name"]
        local hireable = entity.components["Hireable"]
        local worker = entity.components["Worker"]
        
        -- Si c'est un villageois
        if villager and entityPos and entityDim then
            -- Calculer la distance
            local distance = math.sqrt(
                (playerPos.x - entityPos.position.x)^2 + 
                (playerPos.y - entityPos.position.y)^2
            )
            
            -- Distance de proximité pour les villageois : 80 pixels
            if distance <= 80 then
                local villagerData = {
                    distance = distance,
                    villagerName = entityName and entityName.name or "Villageois",
                    canRecruit = false,
                    canMenu = false
                }
                
                -- Vérifier si recrutables (Hireable)
                if hireable and playerWallet then
                    villagerData.canRecruit = true
                    villagerData.type = "Hireable"
                    villagerData.cost = 25
                    villagerData.canAfford = playerWallet.wallet >= 25
                    villagerData.playerGold = playerWallet.wallet
                end
                
                -- Vérifier si Workers (menu contextuel)
                if worker and playerClan and entityClan then
                    local isOwner = playerClan.clanName == entityClan.clanName
                    villagerData.canMenu = isOwner
                    villagerData.type = "Worker"
                    villagerData.isOwner = isOwner
                    villagerData.clanName = entityClan.clanName
                end
                
                nearbyVillagers[entity.id] = villagerData
            end
        end
    end
    
    return nearbyVillagers
end

function WorldServer:tryMining()
    -- Trouver une mine proche et disponible
    local nearbyMines = self:calculateNearbyMines()
    local availableMineId = nil
    
    for mineId, mineData in pairs(nearbyMines) do
        if mineData.canMine and mineData.goldAmount > 0 then
            availableMineId = mineId
            break
        end
    end
    
    if availableMineId then
        -- Envoyer la demande de mining au serveur via UDP
        self.udp:send(_G.bitser.dumps({
            id = "player_mine",
            data = {
                mineId = availableMineId
            }
        }))
        print("[CLIENT] Demande de mining envoyée pour mine:", availableMineId)
        return true
    else
        print("[CLIENT] Aucune mine disponible à proximité")
        return false
    end
end

function WorldServer:tryRecruitment()
    -- Trouver un villageois recrutables proche
    local nearbyVillagers = self:calculateNearbyVillagers()
    local availableVillagerId = nil
    
    for villagerId, villagerData in pairs(nearbyVillagers) do
        if villagerData.canRecruit and villagerData.canAfford then
            availableVillagerId = villagerId
            break
        end
    end
    
    if availableVillagerId then
        -- Envoyer la demande de recrutement au serveur via TCP
        self.tcp:send(_G.bitser.dumps({
            id = "player_recruit_villager",
            data = {
                villagerId = availableVillagerId
            }
        }))
        print("[CLIENT] Demande de recrutement envoyée pour villageois:", availableVillagerId)
        return true
    else
        print("[CLIENT] Aucun villageois recrutables ou pas assez d'or")
        return false
    end
end

function WorldServer:tryOpenVillagerMenu()
    -- Trouver un villageois worker proche
    local nearbyVillagers = self:calculateNearbyVillagers()
    local availableVillagerId = nil
    
    for villagerId, villagerData in pairs(nearbyVillagers) do
        if villagerData.canMenu and villagerData.isOwner then
            availableVillagerId = villagerId
            break
        end
    end
    
    if availableVillagerId then
        -- Envoyer la demande d'ouverture de menu au serveur via TCP
        self.tcp:send(_G.bitser.dumps({
            id = "player_open_villager_menu",
            data = {
                villagerId = availableVillagerId
            }
        }))
        print("[CLIENT] Demande d'ouverture menu pour villageois:", availableVillagerId)
        return true
    else
        print("[CLIENT] Aucun villageois worker proche ou pas propriétaire")
        return false
    end
end

function WorldServer:assignTaskToVillager(villagerId, taskId)
    -- Envoyer la demande d'assignation de tâche au serveur via TCP
    self.tcp:send(_G.bitser.dumps({
        id = "player_assign_task",
        data = {
            villagerId = villagerId,
            taskId = taskId
        }
    }))
    print("[CLIENT] Demande d'assignation tâche pour villageois:", villagerId, "→ Tâche:", taskId)
    return true
end

function WorldServer:hasNearbyMines()
    local nearbyMines = self:calculateNearbyMines()
    for mineId, mineData in pairs(nearbyMines) do
        if mineData.canMine and mineData.goldAmount > 0 then
            return true
        end
    end
    return false
end

function WorldServer:hasNearbyVillagers()
    local nearbyVillagers = self:calculateNearbyVillagers()
    for villagerId, villagerData in pairs(nearbyVillagers) do
        if villagerData.canRecruit or villagerData.canMenu then
            return true
        end
    end
    return false
end

function WorldServer:setUIManager(uiManager)
    self.uiManager = uiManager
end

function WorldServer:getMiningInfo()
    -- Récupérer l'or depuis l'entité joueur
    local playerGold = 0
    local maxGold = 100
    
    if self.world and self.world.entities then
        for _, entity in ipairs(self.world.entities) do
            if entity.id == _G.user.email then -- L'ID du joueur est son email
                local wallet = entity.components and entity.components["Wallet"]
                if wallet then
                    playerGold = wallet.wallet or 0
                    maxGold = wallet.maxWallet or 100
                end
                break
            end
        end
    end
    
    return {
        playerGold = playerGold,
        maxGold = maxGold,
        nearbyMines = self:calculateNearbyMines(),
        hasAvailableMines = self:hasNearbyMines()
    }
end

function WorldServer:getVillagerInfo()
    -- Récupérer l'or depuis l'entité joueur
    local playerGold = 0
    local maxGold = 100
    
    if self.world and self.world.entities then
        for _, entity in ipairs(self.world.entities) do
            if entity.id == _G.user.email then -- L'ID du joueur est son email
                local wallet = entity.components and entity.components["Wallet"]
                if wallet then
                    playerGold = wallet.wallet or 0
                    maxGold = wallet.maxWallet or 100
                end
                break
            end
        end
    end
    
    return {
        playerGold = playerGold,
        maxGold = maxGold,
        nearbyVillagers = self:calculateNearbyVillagers(),
        hasAvailableVillagers = self:hasNearbyVillagers()
    }
end

return WorldServer
