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

-- Entities
local GoldMineEntity    = require(_G.entitiesDir .. "entity-goldmine")

function RealmWorld:initialize()
    World.initialize(self)

    self.width = 2000
    self.height = 2000
    
    -- Configuration debug pour les systèmes
    self.debugInteraction = false -- Changez à true pour activer les logs du système d'interaction
    
    -- Systèmes de jeu
    -- self:addSystem(DeathSystem:new(self))
    -- self:addSystem(WorldBossSystem:new(self))
    -- self:addSystem(MotherSystem:new(self))
    -- self:addSystem(EntityAiSystem:new(self))
    
    self:addSystem(ProjectileSystem:new(self))
    self:addSystem(NatureSystem:new(self))
    self:addSystem(WorldLimitSystem:new(self))
    self:addSystem(DestroySystem:new(self))
    
    -- Nouveau système d'interaction pour les mines (avec option debug)
    self.interactionSystem = InteractionSystem:new(self, self.debugInteraction)
    self:addSystem(self.interactionSystem)
    
    -- Système de nettoyage automatique des connexions
    self.connectionCleanupSystem = ConnectionCleanupSystem:new(self)
    self:addSystem(self.connectionCleanupSystem)
    
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
    return self.interactionSystem:handleMiningRequest(playerId, mineId)
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

return RealmWorld
