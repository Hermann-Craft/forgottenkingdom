local VillagerSpawnSystem = require(_G.libDir .. "middleclass")("VillagerSpawnSystem")
local System = require(_G.engineDir .. "system")
VillagerSpawnSystem.static.super = System

local VillagerEntity = require(_G.entitiesDir .. "entity-villager")
local Compositions = require(_G.gameDir .. "compositions")

function VillagerSpawnSystem:initialize(world, debugMode)
    System.initialize(self, world)
    self.debugMode = debugMode or false
    
    -- Configuration du spawn
    self.MAX_SAVAGE_VILLAGERS = 4
    self.spawnTimer = 0
    self.spawnInterval = 10.0  -- 10 secondes entre les tentatives de spawn
    self.initialSpawnDone = false  -- Flag pour le spawn initial immédiat
    
    -- Zones de spawn prédéfinies (autour du centre de la carte)
    self.spawnZones = {
        { x = 200, y = 150, radius = 50 },
        { x = 600, y = 200, radius = 50 },
        { x = 400, y = 500, radius = 50 },
        { x = 100, y = 400, radius = 50 }
    }
    
    if self.debugMode then
        print("[VILLAGER SPAWN] Système initialisé - Max villageois:", self.MAX_SAVAGE_VILLAGERS)
    end
end

function VillagerSpawnSystem:update(dt)
    -- SPAWN IMMÉDIAT au premier update pour éviter le délai initial
    if not self.initialSpawnDone then
        self.initialSpawnDone = true
        self:performInitialSpawns()
        return
    end
    
    self.spawnTimer = self.spawnTimer + dt
    
    -- Vérifier s'il faut tenter un spawn
    if self.spawnTimer >= self.spawnInterval then
        self.spawnTimer = 0
        self:attemptSpawn()
    end
end

function VillagerSpawnSystem:performInitialSpawns()
    -- Spawn immédiat de tous les villageois au démarrage
    if self.debugMode then
        print("[VILLAGER SPAWN] 🚀 Spawn initial immédiat - Création de", self.MAX_SAVAGE_VILLAGERS, "villageois")
    end
    
    for i = 1, self.MAX_SAVAGE_VILLAGERS do
        -- Utiliser toutes les zones de spawn disponibles
        local spawnZone = self.spawnZones[((i-1) % #self.spawnZones) + 1]
        local spawnPos = self:getRandomPositionInZone(spawnZone)
        
        local villagerId = self:generateVillagerId()
        local villagerData = {
            position = spawnPos,
            orientation = love.math.random() * 2 * math.pi,
            name = self:generateVillagerName(),
            speed = 30
        }
        
        local villager = VillagerEntity:new(villagerId, villagerData)
        self.world:addEntity(villager)
        
        if self.debugMode then
            print("[VILLAGER SPAWN] ✅ Villageois", i, "spawné:", villagerId, "à", spawnPos.x, spawnPos.y)
        end
    end
end

function VillagerSpawnSystem:attemptSpawn()
    -- Compter les villageois sauvages actuels (avec tag Hireable)
    local savageVillagers = self.world:getEntitiesWithAtLeast({"Villager", "Hireable"})
    local currentCount = #savageVillagers
    
    if self.debugMode then
        print("[VILLAGER SPAWN] Villageois sauvages actuels:", currentCount, "/", self.MAX_SAVAGE_VILLAGERS)
    end
    
    -- Si on a déjà le maximum, ne pas spawner
    if currentCount >= self.MAX_SAVAGE_VILLAGERS then
        if self.debugMode then
            print("[VILLAGER SPAWN] Maximum atteint, pas de spawn")
        end
        return
    end
    
    -- Choisir une zone de spawn aléatoire
    local spawnZone = self.spawnZones[love.math.random(1, #self.spawnZones)]
    local spawnPos = self:getRandomPositionInZone(spawnZone)
    
    -- Créer le villageois
    local villagerId = self:generateVillagerId()
    local villagerData = {
        position = spawnPos,
        orientation = love.math.random() * 2 * math.pi,
        name = self:generateVillagerName(),
        speed = 30  -- Vitesse lente pour les sauvages
    }
    
    local villager = VillagerEntity:new(villagerId, villagerData)
    self.world:addEntity(villager)
    
    if self.debugMode then
        print("[VILLAGER SPAWN] Nouveau villageois spawné:", villagerId, "à", spawnPos.x, spawnPos.y)
    end
end

function VillagerSpawnSystem:getRandomPositionInZone(zone)
    local angle = love.math.random() * 2 * math.pi
    local distance = love.math.random() * zone.radius
    
    return {
        x = zone.x + math.cos(angle) * distance,
        y = zone.y + math.sin(angle) * distance
    }
end

function VillagerSpawnSystem:generateVillagerId()
    return "villager_" .. _G.uuid()
end

function VillagerSpawnSystem:generateVillagerName()
    local names = {
        "Aldric", "Brenna", "Caelan", "Dara", "Eamon", "Fiona",
        "Gareth", "Hilda", "Ivan", "Jora", "Kael", "Lyra",
        "Magnus", "Nora", "Osric", "Petra", "Quinn", "Rhea",
        "Soren", "Tara", "Ulric", "Vera", "Willem", "Yara"
    }
    
    return names[love.math.random(1, #names)]
end

-- Méthode pour forcer un spawn (utile pour les tests)
function VillagerSpawnSystem:forceSpawn(position)
    position = position or { x = 400, y = 300 }
    
    local villagerId = self:generateVillagerId()
    local villagerData = {
        position = position,
        orientation = 0,
        name = "Test " .. self:generateVillagerName()
    }
    
    local villager = VillagerEntity:new(villagerId, villagerData)
    self.world:addEntity(villager)
    
    if self.debugMode then
        print("[VILLAGER SPAWN] Spawn forcé:", villagerId)
    end
    
    return villager
end

return VillagerSpawnSystem 
