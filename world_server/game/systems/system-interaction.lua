-- Système d'interaction pour gérer les interactions joueur-mine
local InteractionSystem = require(_G.libDir .. "middleclass")("InteractionSystem")
local Compositions = require(_G.gameDir .. "compositions")

-- Nouveau serializer pour la compatibilité avec le client
local Serializer = require(_G.libDir .. "serializer")

function InteractionSystem:initialize(world, debugMode)
    self.world = world
    self.debugMode = debugMode or false
    self.interactionDistance = 100 -- Distance en pixels pour l'interaction
    
    -- Tracking des joueurs près des mines
    self.playersNearMines = {} -- {playerId = {mineId = true}}
    
    if self.debugMode then
        print("[INTERACTION] Système d'interaction initialisé avec debug")
    end
end

function InteractionSystem:update(dt)
    -- Obtenir toutes les entités mines et joueurs
    local mines = self.world:getEntitiesWithStrict(Compositions.Mine)
    local players = self.world:getEntitiesWithStrict(Compositions.Player)
    
    -- Debug: afficher les données importantes (seulement si debug activé)
    if self.debugMode and #players > 0 then
        print("[INTERACTION] ✅ Joueurs connectés:", #players, "Mines:", #mines)
        for i, player in ipairs(players) do
            local pos = player:getComponent("Position")
            if pos then
                print("  - Joueur", player.id, "à position:", pos.position.x, pos.position.y)
            end
        end
    end
    
    -- Vérifier la proximité entre joueurs et mines
    self:checkProximity(players, mines)
    
    -- Mettre à jour les mines (respawn, état, etc.)
    self:updateMines(mines, dt)
end

function InteractionSystem:checkProximity(players, mines)
    local currentNearby = {}
    
    for _, player in ipairs(players) do
        local playerPos = player:getComponent("Position")
        if not playerPos then
            if self.debugMode then
                print("[INTERACTION] ❌ Joueur", player.id, "n'a pas de composant Position")
            end
            goto continue_player
        end
        
        local playerId = player.id
        if self.debugMode then
            print("[INTERACTION] 🔍 Vérification joueur", playerId, "à position", playerPos.position.x, playerPos.position.y)
        end
        
        currentNearby[playerId] = {}
        
        for _, mine in ipairs(mines) do
            local minePos = mine:getComponent("Position")
            local mineDim = mine:getComponent("Dimension")
            if not minePos or not mineDim then
                if self.debugMode then
                    print("[INTERACTION] ❌ Mine", mine.id, "manque composant Position ou Dimension")
                end
                goto continue_mine
            end
            
            local mineId = mine.id
            
            -- Calculer la distance entre joueur et mine
            local distance = self:calculateDistance(playerPos.position, minePos.position, mineDim)
            if self.debugMode then
                print("[INTERACTION] 📏 Distance entre joueur", playerId, "et mine", mineId, ":", distance, "pixels (seuil:", self.interactionDistance, ")")
            end
            
            if distance <= self.interactionDistance then
                -- Joueur est proche de la mine
                currentNearby[playerId][mineId] = true
                if self.debugMode then
                    print("[INTERACTION] ✅ Joueur", playerId, "est PROCHE de la mine", mineId)
                end
                
                -- Vérifier si c'est une nouvelle proximité
                if not (self.playersNearMines[playerId] and self.playersNearMines[playerId][mineId]) then
                    self:onPlayerNearMine(playerId, mineId, mine)
                end
            else
                if self.debugMode then
                    print("[INTERACTION] ❌ Joueur", playerId, "est LOIN de la mine", mineId)
                end
            end
            
            ::continue_mine::
        end
        
        ::continue_player::
    end
    
    -- Détecter les joueurs qui se sont éloignés
    for playerId, mines in pairs(self.playersNearMines) do
        for mineId, _ in pairs(mines) do
            if not (currentNearby[playerId] and currentNearby[playerId][mineId]) then
                self:onPlayerLeftMine(playerId, mineId)
            end
        end
    end
    
    -- Mettre à jour le tracking
    self.playersNearMines = currentNearby
end

function InteractionSystem:calculateDistance(playerPos, minePos, mineDim)
    -- Calculer la distance entre le centre du joueur et le centre de la mine
    local playerCenterX = playerPos.x + 16 -- Assumant 32x32 joueur
    local playerCenterY = playerPos.y + 16
    local mineCenterX = minePos.x + mineDim.width / 2
    local mineCenterY = minePos.y + mineDim.height / 2
    
    local dx = playerCenterX - mineCenterX
    local dy = playerCenterY - mineCenterY
    
    return math.sqrt(dx * dx + dy * dy)
end

function InteractionSystem:onPlayerNearMine(playerId, mineId, mine)
    -- Envoyer un message au client pour indiquer qu'il peut miner
    local resources = mine:getComponent("Resources")
    
    if _G.Server and _G.Server.Tcp then
        _G.Server.Tcp:send(_G.bitser.dumps({
            id = "mining_available",
            data = {
                mineId = mineId,
                canMine = resources:canHarvest(),
                goldAmount = resources.goldAmount,
                maxGold = resources.maxGold,
                state = resources.state
            }
        }), _G.Server.Clients[playerId] and _G.Server.Clients[playerId].tcp)
    end
    
    if self.debugMode then
        print("[INTERACTION] Joueur", playerId, "près de la mine", mineId)
    end
end

function InteractionSystem:onPlayerLeftMine(playerId, mineId)
    -- Envoyer un message au client pour indiquer qu'il ne peut plus miner
    if _G.Server and _G.Server.Tcp then
        _G.Server.Tcp:send(_G.bitser.dumps({
            id = "mining_unavailable",
            data = {
                mineId = mineId
            }
        }), _G.Server.Clients[playerId] and _G.Server.Clients[playerId].tcp)
    end
    
    if self.debugMode then
        print("[INTERACTION] Joueur", playerId, "s'est éloigné de la mine", mineId)
    end
end

function InteractionSystem:updateMines(mines, dt)
    for _, mine in ipairs(mines) do
        -- Mettre à jour chaque mine (respawn, cooldown, etc.)
        mine:update(dt)
    end
end

function InteractionSystem:handleMiningRequest(playerId, mineId)
    -- Vérifier que le joueur est toujours près de la mine
    if not (self.playersNearMines[playerId] and self.playersNearMines[playerId][mineId]) then
        return {
            success = false,
            reason = "too_far",
            message = "Vous êtes trop loin de la mine!"
        }
    end
    
    -- Obtenir les entités joueur et mine
    local player = self.world:getEntityById(playerId)
    local mine = self.world:getEntityById(mineId)
    
    if not player or not mine then
        return {
            success = false,
            reason = "entity_not_found",
            message = "Joueur ou mine introuvable!"
        }
    end
    
    -- Vérifier le portefeuille du joueur
    local playerWallet = player:getComponent("Wallet")
    if playerWallet:isFull() then
        return {
            success = false,
            reason = "wallet_full",
            message = "Votre portefeuille est plein! (" .. playerWallet:getGoldRatio() .. ")"
        }
    end
    
    -- Vérifier si la mine peut être récoltée
    local resources = mine:getComponent("Resources")
    if not resources:canHarvest() then
        if resources.goldAmount <= 0 then
            return {
                success = false,
                reason = "mine_empty",
                message = "Cette mine est épuisée! Rechargement en cours..."
            }
        else
            return {
                success = false,
                reason = "cooldown",
                message = "Attendez avant de miner à nouveau!"
            }
        end
    end
    
    -- Effectuer la récolte
    local harvestAmount = love.math.random(5, 15) -- 5-15 or par récolte
    local actualHarvested = resources:harvest(harvestAmount)
    
    -- Ajouter l'or au portefeuille du joueur
    local goldAdded, goldExcess = playerWallet:addGold(actualHarvested)
    
    -- Si on n'a pas pu tout ajouter, remettre la différence dans la mine
    if goldExcess > 0 then
        resources.goldAmount = resources.goldAmount + goldExcess
    end
    
    -- Notifier tous les joueurs proches du changement d'état de la mine
    self:notifyMineStateChange(mine)
    
    return {
        success = true,
        goldHarvested = goldAdded,
        newWalletTotal = playerWallet.wallet,
        mineGoldLeft = resources.goldAmount,
        mineState = resources.state
    }
end

function InteractionSystem:notifyMineStateChange(mine)
    local resources = mine:getComponent("Resources")
    
    -- Notifier tous les clients connectés du changement d'état
    for playerId, clientData in pairs(_G.Server.Clients or {}) do
        if clientData.tcp then
            _G.Server.Tcp:send(_G.bitser.dumps({
                id = "mine_state_update",
                data = {
                    mineId = mine.id,
                    goldAmount = resources.goldAmount,
                    maxGold = resources.maxGold,
                    state = resources.state,
                    respawnTimer = resources.respawnTimer
                }
            }), clientData.tcp)
        end
    end
end

-- Méthode pour activer/désactiver le mode debug à la volée
function InteractionSystem:setDebugMode(enabled)
    self.debugMode = enabled
    if enabled then
        print("[INTERACTION] 🔧 Mode debug ACTIVÉ")
    else
        print("[INTERACTION] 🔧 Mode debug DÉSACTIVÉ")
    end
end

return InteractionSystem 
