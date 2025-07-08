-- Système d'interaction refactorisé - CALCUL CLIENT-SIDE
-- Le client calcule maintenant lui-même les proximités via world.entities
-- Ce système ne gère plus que les validations côté serveur pour les actions critiques
local InteractionSystem = require(_G.libDir .. "middleclass")("InteractionSystem")
local System = require(_G.engineDir .. "system")
InteractionSystem.static.super = System

local CollisionSystem = require(_G.systemsDir .. "system-collision")

function InteractionSystem:initialize(world, debugMode)
    System.initialize(self, world)
    self.debugMode = debugMode or false
    
    -- Créer le système de collision performant pour validations serveur
    self.collisionSystem = CollisionSystem:new(world, debugMode)
    
    -- Système de grâce pour éviter les problèmes de timing lors des validations
    self.villagerInteractionGrace = {} -- {playerId = {villagerId = timestamp}}
    self.graceTime = 2.0 -- 2 secondes de grâce
    
    if self.debugMode then
        print("[INTERACTION] 🚀 Système d'interaction CLIENT-SIDE initialisé")
        print("[INTERACTION] Le client calcule maintenant les proximités lui-même")
    end
end

function InteractionSystem:update(dt)
    -- Nettoyer les timestamps de grâce expirés (nettoyage moins fréquent)
    self:cleanupGraceTimestamps()
    
    -- Mettre à jour le système de collision pour les validations serveur
    self.collisionSystem:update(dt)
end

-- === MÉTHODES DE VALIDATION SERVEUR ===

function InteractionSystem:updateMines(mines, dt)
    for _, mine in ipairs(mines) do
        -- Mettre à jour chaque mine (respawn, cooldown, etc.)
        mine:update(dt)
    end
end

function InteractionSystem:handleMiningRequest(playerId, mineId)
    -- Validation serveur de la proximité (sans envoi de messages de proximité)
    local player = self.world:getEntityById(playerId)
    local mine = self.world:getEntityById(mineId)
    
    if not player or not mine then
        return {
            success = false,
            reason = "entity_not_found",
            message = "Joueur ou mine introuvable!"
        }
    end
    
    -- Validation de proximité avec SAT
    local playerRect = self.collisionSystem:createEntityRect(player)
    local mineRect = self.collisionSystem:createEntityRect(mine)
    
    if not playerRect or not mineRect then
        return {
            success = false,
            reason = "collision_error", 
            message = "Erreur de collision!"
        }
    end
    
    local isColliding = self.collisionSystem:detectCollision(playerRect, mineRect)
    
    if not isColliding then
        return {
            success = false,
            reason = "too_far",
            message = "Vous êtes trop loin de la mine!"
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

-- === VALIDATION VILLAGEOIS ===

-- Vérifier si un joueur peut interagir avec un villageois (proximité + grâce)
function InteractionSystem:canPlayerInteractWithVillager(playerId, villagerId)
    local player = self.world:getEntityById(playerId)
    local villager = self.world:getEntityById(villagerId)
    
    if not player or not villager then
        return false
    end
    
    -- Validation de proximité avec SAT
    local playerRect = self.collisionSystem:createEntityRect(player)
    local villagerRect = self.collisionSystem:createEntityRect(villager)
    
    if not playerRect or not villagerRect then
        return false
    end
    
    local isColliding = self.collisionSystem:detectCollision(playerRect, villagerRect)
    
    -- Vérifier la grâce si pas de collision directe
    if not isColliding then
        return self:isInGrace(playerId, villagerId)
    end
    
    return true
end

-- Ajouter un villageois à la grâce pour éviter les problèmes de timing
function InteractionSystem:addToGrace(playerId, villagerId)
    if not self.villagerInteractionGrace[playerId] then
        self.villagerInteractionGrace[playerId] = {}
    end
    
    local currentTime = love.timer.getTime()
    
    -- 🔧 PROTECTION ANTI-SPAM: Vérifier si la grâce a déjà été ajoutée récemment
    local existingGrace = self.villagerInteractionGrace[playerId][villagerId]
    if existingGrace and (currentTime - existingGrace) < 1.0 then
        -- Grâce déjà active et récente, ne pas spammer
        return
    end
    
    self.villagerInteractionGrace[playerId][villagerId] = currentTime
    
    if self.debugMode then
        print("[INTERACTION] 🕐 Grâce ajoutée - Joueur", playerId, "→ Villageois", villagerId, "pour", self.graceTime, "secondes")
    end
end

-- Nettoyer les timestamps de grâce expirés (appelé moins fréquemment)
function InteractionSystem:cleanupGraceTimestamps()
    local currentTime = love.timer.getTime()
    local cleanedCount = 0
    local playersToClean = {}
    
    for playerId, villagers in pairs(self.villagerInteractionGrace) do
        local villagersToClean = {}
        
        for villagerId, timestamp in pairs(villagers) do
            if currentTime - timestamp > self.graceTime then
                table.insert(villagersToClean, villagerId)
                cleanedCount = cleanedCount + 1
            end
        end
        
        -- Supprimer les villageois expirés
        for _, villagerId in ipairs(villagersToClean) do
            villagers[villagerId] = nil
        end
        
        -- Marquer le joueur pour nettoyage si plus de villageois
        if next(villagers) == nil then
            table.insert(playersToClean, playerId)
        end
    end
    
    -- Nettoyer les joueurs vides
    for _, playerId in ipairs(playersToClean) do
        self.villagerInteractionGrace[playerId] = nil
    end
    
    if self.debugMode and cleanedCount > 0 then
        print("[INTERACTION] 🧹 Nettoyage grâce:", cleanedCount, "timestamps expirés supprimés")
    end
end

-- Vérifier si un joueur est en période de grâce pour un villageois
function InteractionSystem:isInGrace(playerId, villagerId)
    if not self.villagerInteractionGrace[playerId] then
        return false
    end
    
    local graceTimestamp = self.villagerInteractionGrace[playerId][villagerId]
    if not graceTimestamp then
        return false
    end
    
    local currentTime = love.timer.getTime()
    local timeInGrace = currentTime - graceTimestamp
    
    return timeInGrace <= self.graceTime
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
