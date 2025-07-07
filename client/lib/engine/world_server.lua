local WorldServer = require(_G.libDir .. "middleclass")("WorldServer")
local World = require(_G.engineDir .. "world")
local Serializer = require(_G.libDir .. "serializer")

function WorldServer:initialize(characterName)
    self.currentCharacter = characterName
    self.tcp = require(_G.libDir .. "tcp_client"):new()
    self.udp = require(_G.libDir .. "udp_client"):new()
    self.world = nil
    
    -- Mining system
    self.nearbyMines = {} -- Table des mines à proximité {mineId = {canMine, goldAmount, maxGold, state}}
    self.uiManager = nil -- Sera assigné par la scene

    self.tcp.callbacks.recv = function (data)
        local packet = _G.bitser.loads(data)
        
        -- Vérifier que packet est bien une table
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
        elseif packet.id == "mining_available" then
            -- Une mine est devenue disponible pour le mining
            self.nearbyMines[packet.data.mineId] = {
                canMine = packet.data.canMine,
                goldAmount = packet.data.goldAmount,
                maxGold = packet.data.maxGold,
                state = packet.data.state
            }
            print("[MINING] Mine disponible:", packet.data.mineId, "- Or:", packet.data.goldAmount .. "/" .. packet.data.maxGold)
        elseif packet.id == "mining_unavailable" then
            -- Le joueur s'est éloigné d'une mine
            self.nearbyMines[packet.data.mineId] = nil
            print("[MINING] Mine indisponible:", packet.data.mineId)
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
            
            -- Mettre à jour notre cache si on est près de cette mine
            if self.nearbyMines[packet.data.mineId] then
                self.nearbyMines[packet.data.mineId].goldAmount = packet.data.goldAmount
                self.nearbyMines[packet.data.mineId].state = packet.data.state
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

function WorldServer:tryMining()
    -- Trouver une mine proche et disponible
    local availableMineId = nil
    for mineId, mineData in pairs(self.nearbyMines) do
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

function WorldServer:hasNearbyMines()
    for mineId, mineData in pairs(self.nearbyMines) do
        if mineData.canMine and mineData.goldAmount > 0 then
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
        nearbyMines = self.nearbyMines,
        hasAvailableMines = self:hasNearbyMines()
    }
end

return WorldServer
