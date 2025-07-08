local World = require(_G.engineDir .. "world")
local RealmWorld = require(_G.libDir .. "middleclass")("RealmWorld", World)

local random = math.random
local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Systems
-- local DeathSystem       = require(_G.baseDir .. "game.systems.system-death")
-- local WorldBossSystem   = require(_G.baseDir .. "game.systems.system-world_boss")
-- local MotherSystem      = require(_G.baseDir .. "game.systems.system-mother")
-- local EntityAiSystem    = require(_G.baseDir .. "game.systems.system-entity_ai")
local DestroySystem     = require(_G.baseDir .. "game.systems.system-destroy")
local ProjectileSystem  = require(_G.baseDir .. "game.systems.system-projectile")
local WorldLimitSystem  = require(_G.baseDir .. "game.systems.system-world_limit")
local NatureSystem      = require(_G.baseDir .. "game.systems.system-nature")
local InteractionSystem = require(_G.baseDir .. "game.systems.system-interaction")
local ConnectionCleanupSystem = require(_G.baseDir .. "game.systems.system-connection-cleanup")
-- Systèmes villageois (Phase 2-5)
local VillagerSpawnSystem = require(_G.baseDir .. "game.systems.system-villager-spawn")
local VillagerAISystem = require(_G.baseDir .. "game.systems.system-villager-ai")
local RecruitSystem = require(_G.baseDir .. "game.systems.system-recruit")
local ContextMenuSystem = require(_G.baseDir .. "game.systems.system-context-menu")
local TreeSpawnSystem = require(_G.baseDir .. "game.systems.system-tree-spawn")  -- Phase 5

-- Entities
local GoldMineEntity    = require(_G.entitiesDir .. "entity-goldmine")

function RealmWorld:initialize()
    World.initialize(self)

    self.width = 2000
    self.height = 2000
    
    -- Configuration debug pour les systèmes
    self.debugInteraction = true -- Changez à true pour activer les logs du système d'interaction
    self.debugVillagers = false -- Debug villageois activé par défaut pour la phase 2
    
    -- Systèmes de jeu
    -- self:addSystem(DeathSystem:new(self))
    -- self:addSystem(WorldBossSystem:new(self))
    -- self:addSystem(MotherSystem:new(self))
    -- self:addSystem(EntityAiSystem:new(self))
    
    self:addSystem(ProjectileSystem:new(self))
    self:addSystem(NatureSystem:new(self))
    self:addSystem(WorldLimitSystem:new(self))
    self:addSystem(DestroySystem:new(self))
    
    -- 🚀 SYSTÈME D'INTERACTION REFACTORISÉ (utilise collision performante)
    print("[WORLD] 🚀 Utilisation du système d'interaction REFACTORISÉ")
    self.interactionSystem = InteractionSystem:new(self, self.debugInteraction)
    self:addSystem(self.interactionSystem)
    
    -- Système de nettoyage automatique des connexions
    self.connectionCleanupSystem = ConnectionCleanupSystem:new(self)
    self:addSystem(self.connectionCleanupSystem)
    
    -- Systèmes de villageois (Phase 2-4)
    self.villagerSpawnSystem = VillagerSpawnSystem:new(self, self.debugVillagers)
    self:addSystem(self.villagerSpawnSystem)
    
    self.villagerAISystem = VillagerAISystem:new(self, self.debugVillagers)
    self:addSystem(self.villagerAISystem)
    
    self.recruitSystem = RecruitSystem:new(self, self.debugVillagers)  -- Phase 3
    self:addSystem(self.recruitSystem)
    
    self.contextMenuSystem = ContextMenuSystem:new(self, self.debugVillagers)  -- Phase 4
    self:addSystem(self.contextMenuSystem)
    
    self.treeSpawnSystem = TreeSpawnSystem:new(self)  -- Phase 5
    self:addSystem(self.treeSpawnSystem)
    
    -- Générer les mines d'or dans le monde
    self:generateGoldMines()
end

function RealmWorld:generateGoldMines()
    local numberOfMines = love.math.random(5, 8) -- 5-8 mines d'or
    local minDistanceBetweenMines = 200 -- Distance minimale entre les mines
    local borderMargin = 100 -- Marge depuis les bords du monde
    
    local minePositions = {}
    
    print("[WORLD] Génération de", numberOfMines, "mines d'or...")
    
    for i = 1, numberOfMines do
        local attempts = 0
        local maxAttempts = 50
        local validPosition = false
        local x, y
        
        -- Essayer de trouver une position valide
        while not validPosition and attempts < maxAttempts do
            x = love.math.random(borderMargin, self.width - borderMargin)
            y = love.math.random(borderMargin, self.height - borderMargin)
            
            validPosition = true
            
            -- Vérifier la distance avec les autres mines
            for _, pos in ipairs(minePositions) do
                local distance = math.sqrt((x - pos.x)^2 + (y - pos.y)^2)
                if distance < minDistanceBetweenMines then
                    validPosition = false
                    break
                end
            end
            
            attempts = attempts + 1
        end
        
        if validPosition then
            -- Créer la mine d'or
            local mineId = uuid()
            local goldAmount = love.math.random(60, 100) -- 60-100 or initial
            local maxGold = 100
            
            local goldMine = GoldMineEntity:new(mineId, { x = x, y = y }, goldAmount, maxGold)
            self:addEntity(goldMine)
            
            table.insert(minePositions, { x = x, y = y })
            
            print("  ✓ Mine", i, "créée à position", x, y, "avec", goldAmount, "or")
        else
            print("  ✗ Impossible de placer la mine", i, "après", maxAttempts, "tentatives")
        end
    end
    
    print("[WORLD]", #minePositions, "mines d'or générées avec succès")
end

function RealmWorld:handleMiningRequest(playerId, mineId)
    -- Déléguer la gestion de la récolte au système d'interaction
    if self.interactionSystem then
        -- Pour le système optimisé, implémenter la logique de minage complète
        
        -- Vérifier la proximité via le système de collision
        if not self.interactionSystem.collisionSystem:isPlayerNearMine(playerId, mineId) then
            return {
                success = false,
                reason = "too_far",
                message = "Vous êtes trop loin de la mine!"
            }
        end
        
        -- Obtenir les entités joueur et mine
        local player = self:getEntityById(playerId)
        local mine = self:getEntityById(mineId)
        
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
    else
        return {
            success = false,
            reason = "interaction_system_not_initialized",
            message = "Le système d'interaction n'est pas initialisé."
        }
    end
end

-- Méthode pour notifier le changement d'état des mines (système optimisé)
function RealmWorld:notifyMineStateChange(mine)
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

-- Méthodes pour contrôler le debug à la volée
function RealmWorld:setInteractionDebug(enabled)
    self.debugInteraction = enabled
    if self.interactionSystem then
        self.interactionSystem:setDebugMode(enabled)
    end
end

function RealmWorld:toggleInteractionDebug()
    self:setInteractionDebug(not self.debugInteraction)
    return self.debugInteraction
end

-- Méthodes pour contrôler le système de nettoyage des connexions
function RealmWorld:setConnectionCleanupDebug(enabled)
    if self.connectionCleanupSystem then
        self.connectionCleanupSystem:setDebugMode(enabled)
    end
end

function RealmWorld:forceConnectionCleanup()
    if self.connectionCleanupSystem then
        self.connectionCleanupSystem:forceCleanup()
    end
end

function RealmWorld:getConnectionStats()
    if self.connectionCleanupSystem then
        return self.connectionCleanupSystem:getConnectionStats()
    end
    return {}
end

-- Méthodes pour contrôler les systèmes de villageois
function RealmWorld:setVillagerDebug(enabled)
    self.debugVillagers = enabled
    if self.villagerSpawnSystem then
        self.villagerSpawnSystem.debugMode = enabled
    end
    if self.villagerAISystem then
        self.villagerAISystem.debugMode = enabled
    end
end

function RealmWorld:toggleVillagerDebug()
    self:setVillagerDebug(not self.debugVillagers)
    return self.debugVillagers
end

function RealmWorld:forceSpawnVillager(position)
    if self.villagerSpawnSystem then
        return self.villagerSpawnSystem:forceSpawn(position)
    end
    return nil
end

function RealmWorld:getVillagerStats()
    local villagers = self:getEntitiesWithAtLeast({"Villager"})
    local savageVillagers = self:getEntitiesWithAtLeast({"Villager", "Hireable"})
    local workers = self:getEntitiesWithAtLeast({"Villager", "Worker"})
    
    return {
        total = #villagers,
        savage = #savageVillagers,
        workers = #workers
    }
end

-- Méthode pour gérer les demandes de recrutement (Phase 3)
function RealmWorld:handleRecruitmentRequest(playerId, villagerId)
    if self.recruitSystem then
        return self.recruitSystem:handleRecruitmentRequest(playerId, villagerId)
    end
    return {
        success = false,
        reason = "system_not_found",
        message = "Système de recrutement indisponible!"
    }
end

-- Méthodes pour contrôler le système de recrutement
function RealmWorld:getRecruitmentStats()
    if self.recruitSystem then
        return self.recruitSystem:getRecruitmentStats()
    end
    return {}
end

-- Méthodes pour contrôler le système de menu contextuel (Phase 4)
function RealmWorld:handleMenuRequest(playerId, villagerId)
    if self.contextMenuSystem then
        return self.contextMenuSystem:handleMenuRequest(playerId, villagerId)
    end
    return {
        success = false,
        reason = "system_not_found",
        message = "Système de menu contextuel indisponible!"
    }
end

function RealmWorld:handleTaskAssignment(playerId, villagerId, taskId)
    if self.contextMenuSystem then
        return self.contextMenuSystem:handleTaskAssignment(playerId, villagerId, taskId)
    end
    return {
        success = false,
        reason = "system_not_found",
        message = "Système de menu contextuel indisponible!"
    }
end

function RealmWorld:closeVillagerMenu(playerId, villagerId)
    if self.contextMenuSystem then
        local result = self.contextMenuSystem:handleMenuClose(playerId, villagerId)
        
        -- Si on utilise le système optimisé, notifier la fermeture manuelle
        if self.interactionSystem and self.interactionSystem.handleMenuManualClose then
            self.interactionSystem:handleMenuManualClose(playerId, villagerId)
        end
        
        return result
    end
    return {
        success = false,
        reason = "system_not_found",
        message = "Système de menu contextuel indisponible!"
    }
end

function RealmWorld:getMenuStats()
    if self.contextMenuSystem then
        return self.contextMenuSystem:getMenuStats()
    end
    return {}
end

-- Méthodes pour contrôler le système de zones d'arbres (Phase 5)
function RealmWorld:forceSpawnTreeZone(position, config)
    if self.treeSpawnSystem then
        return self.treeSpawnSystem:forceSpawnTreeZone(position, config)
    end
    return nil
end

function RealmWorld:getTreeStats()
    if self.treeSpawnSystem then
        return self.treeSpawnSystem:getTreeStats()
    end
    return {}
end

function RealmWorld:setTreeDebug(enabled)
    if self.treeSpawnSystem then
        self.treeSpawnSystem:toggleDebug()
    end
end

function RealmWorld:toggleTreeDebug()
    if self.treeSpawnSystem then
        self.treeSpawnSystem:toggleDebug()
        return self.treeSpawnSystem.debug
    end
    return false
end

return RealmWorld
