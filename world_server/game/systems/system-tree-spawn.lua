local System = require(_G.libDir .. "engine.system")
local TreeZoneEntity = require(_G.entitiesDir .. "entity-tree-zone")

local TreeSpawnSystem = System:subclass("TreeSpawnSystem")

function TreeSpawnSystem:initialize(world)
    System.initialize(self, world)
    
    -- Configuration du spawn
    self.maxTrees = 6  -- Maximum 6 zones d'arbres dans le monde
    self.spawnTimer = 0
    self.spawnInterval = 15  -- Tentative de spawn toutes les 15 secondes
    self.initialSpawnDone = false  -- Flag pour le spawn initial immédiat
    
    -- Zones de spawn prédéfinies pour les arbres
    self.spawnZones = {
        { x = 200, y = 150, radius = 40 },  -- Nord-Ouest
        { x = 600, y = 120, radius = 40 },  -- Nord-Est  
        { x = 150, y = 400, radius = 40 },  -- Sud-Ouest
        { x = 650, y = 450, radius = 40 },  -- Sud-Est
        { x = 400, y = 100, radius = 40 },  -- Centre-Nord
        { x = 400, y = 500, radius = 40 }   -- Centre-Sud
    }
    
    -- Configurations variées pour les zones d'arbres
    self.treeConfigs = {
        {
            name = "Forêt de Chênes",
            woodAmount = 25,
            maxWood = 25,
            harvestTime = 2.5,
            respawnTime = 45,
            texture = { name = "oak_forest", index = 1, size = { width = 100, height = 100 } },
            dimension = { width = 100, height = 100 }
        },
        {
            name = "Bosquet de Pins",
            woodAmount = 30,
            maxWood = 30,
            harvestTime = 3,
            respawnTime = 60,
            texture = { name = "pine_grove", index = 1, size = { width = 90, height = 90 } },
            dimension = { width = 90, height = 90 }
        },
        {
            name = "Sapinière",
            woodAmount = 20,
            maxWood = 20,
            harvestTime = 2,
            respawnTime = 40,
            texture = { name = "spruce_forest", index = 1, size = { width = 80, height = 80 } },
            dimension = { width = 80, height = 80 }
        }
    }
    
    self.debug = false
    
    -- Stats globales
    self.totalSpawned = 0
    self.nextTreeId = 1
    
    if self.debug then
        print("[TreeSpawnSystem] Initialisé avec " .. self.maxTrees .. " zones max")
    end
end

function TreeSpawnSystem:update(dt)
    -- SPAWN IMMÉDIAT au premier update pour éviter le délai initial
    if not self.initialSpawnDone then
        self.initialSpawnDone = true
        self:performInitialTreeSpawns()
    end
    
    self.spawnTimer = self.spawnTimer + dt
    
    -- Tentative de spawn selon l'intervalle
    if self.spawnTimer >= self.spawnInterval then
        self.spawnTimer = 0
        self:trySpawn()
    end
    
    -- Mise à jour des TreeZones existantes
    self:updateTreeZones(dt)
end

function TreeSpawnSystem:performInitialTreeSpawns()
    -- Spawn immédiat de toutes les zones d'arbres au démarrage
    if self.debug then
        print("[TreeSpawnSystem] 🌲 Spawn initial immédiat - Création de", self.maxTrees, "zones d'arbres")
    end
    
    local spawned = 0
    for i = 1, self.maxTrees do
        -- Utiliser les zones de spawn dans l'ordre
        local spawnZone = self.spawnZones[i]
        if not spawnZone then break end
        
        -- Position aléatoire dans la zone
        local angle = math.random() * 2 * math.pi
        local distance = math.random() * spawnZone.radius * 0.5  -- Plus près du centre
        local spawnPos = {
            x = spawnZone.x + math.cos(angle) * distance,
            y = spawnZone.y + math.sin(angle) * distance
        }
        
        -- Configuration aléatoire
        local configIndex = math.random(1, #self.treeConfigs)
        local config = self.treeConfigs[configIndex]
        
        -- Créer la zone d'arbres
        local treeZone = self:spawnTreeZone(spawnPos, config)
        
        if treeZone then
            spawned = spawned + 1
            if self.debug then
                print("[TreeSpawnSystem] ✅ Arbre", i, "spawné:", treeZone:getComponent("Name").name, 
                      "à (" .. spawnPos.x .. ", " .. spawnPos.y .. ")")
            end
        end
    end
    
    if self.debug then
        print("[TreeSpawnSystem] 🌲 Spawn initial terminé:", spawned, "/", self.maxTrees, "zones créées")
    end
end

function TreeSpawnSystem:trySpawn()
    local currentTrees = self.world:getEntitiesWithAtLeast({"TreeZone"})
    
    if #currentTrees >= self.maxTrees then
        if self.debug then
            print("[TreeSpawnSystem] Limite atteinte: " .. #currentTrees .. "/" .. self.maxTrees)
        end
        return
    end
    
    -- Trouver une zone libre
    local availableZones = self:getAvailableSpawnZones()
    if #availableZones == 0 then
        if self.debug then
            print("[TreeSpawnSystem] Aucune zone de spawn disponible")
        end
        return
    end
    
    -- Choisir une zone aléatoire
    local zoneIndex = math.random(1, #availableZones)
    local spawnZone = availableZones[zoneIndex]
    
    -- Générer position aléatoire dans la zone
    local angle = math.random() * 2 * math.pi
    local distance = math.random() * spawnZone.radius
    local spawnPos = {
        x = spawnZone.x + math.cos(angle) * distance,
        y = spawnZone.y + math.sin(angle) * distance
    }
    
    -- Choisir configuration aléatoire
    local configIndex = math.random(1, #self.treeConfigs)
    local config = self.treeConfigs[configIndex]
    
    -- Créer la zone d'arbres
    local treeZone = self:spawnTreeZone(spawnPos, config)
    
    if self.debug and treeZone then
        print("[TreeSpawnSystem] Spawné: " .. treeZone:getComponent("Name").name .. 
              " à (" .. spawnPos.x .. ", " .. spawnPos.y .. ")")
    end
end

function TreeSpawnSystem:spawnTreeZone(position, config)
    local treeId = "tree_zone_" .. self.nextTreeId
    self.nextTreeId = self.nextTreeId + 1
    
    local treeZone = TreeZoneEntity:new(treeId, position, config)
    self.world:addEntity(treeZone)
    
    self.totalSpawned = self.totalSpawned + 1
    
    return treeZone
end

function TreeSpawnSystem:getAvailableSpawnZones()
    local currentTrees = self.world:getEntitiesWithAtLeast({"TreeZone"})
    local availableZones = {}
    
    for _, spawnZone in ipairs(self.spawnZones) do
        local isOccupied = false
        
        -- Vérifier si cette zone est déjà occupée
        for _, treeZone in ipairs(currentTrees) do
            local treePos = treeZone:getComponent("Position")
            if treePos then
                local distance = math.sqrt((treePos.position.x - spawnZone.x)^2 + (treePos.position.y - spawnZone.y)^2)
                if distance < spawnZone.radius * 0.8 then  -- 80% de la zone pour éviter chevauchement
                    isOccupied = true
                    break
                end
            end
        end
        
        if not isOccupied then
            table.insert(availableZones, spawnZone)
        end
    end
    
    return availableZones
end

function TreeSpawnSystem:updateTreeZones(dt)
    local treeZones = self.world:getEntitiesWithAtLeast({"TreeZone"})
    
    for _, treeZone in ipairs(treeZones) do
        local treeComponent = treeZone:getComponent("TreeZone")
        if treeComponent then
            treeComponent:update(dt)
        end
    end
end

-- Méthodes utilitaires pour debug/tests
function TreeSpawnSystem:forceSpawnTreeZone(position, config)
    position = position or { x = 400, y = 300 }
    config = config or self.treeConfigs[1]
    
    return self:spawnTreeZone(position, config)
end

function TreeSpawnSystem:getTreeStats()
    local treeZones = self.world:getEntitiesWithAtLeast({"TreeZone"})
    local stats = {
        current = #treeZones,
        max = self.maxTrees,
        totalSpawned = self.totalSpawned,
        zones = {}
    }
    
    for _, treeZone in ipairs(treeZones) do
        local treeComponent = treeZone:getComponent("TreeZone")
        local nameComponent = treeZone:getComponent("Name")
        local posComponent = treeZone:getComponent("Position")
        
        if treeComponent and nameComponent and posComponent then
            table.insert(stats.zones, {
                id = treeZone.id,
                name = nameComponent.name,
                position = { x = posComponent.position.x, y = posComponent.position.y },
                woodAmount = treeComponent.woodAmount,
                maxWood = treeComponent.maxWood,
                state = treeComponent.state,
                totalHarvested = treeComponent.totalHarvested
            })
        end
    end
    
    return stats
end

function TreeSpawnSystem:toggleDebug()
    self.debug = not self.debug
    print("[TreeSpawnSystem] Debug: " .. (self.debug and "ON" or "OFF"))
end

return TreeSpawnSystem 
