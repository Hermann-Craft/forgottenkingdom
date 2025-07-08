local TreeZoneComponent = require(_G.libDir .. "middleclass")("TreeZone")

TreeZoneComponent.static.name = "TreeZone"
TreeZoneComponent.static.client = true  -- Visible côté client

function TreeZoneComponent:initialize(woodAmount, maxWood, respawnTime, harvestTime, state)
    -- Ressources disponibles
    self.woodAmount = woodAmount or 20
    self.maxWood = maxWood or 20
    
    -- Temps de respawn après épuisement (en secondes)
    self.respawnTime = respawnTime or 60  -- 1 minute
    self.respawnTimer = 0
    
    -- Temps nécessaire pour récolter 1 bois (en secondes)
    self.harvestTime = harvestTime or 3
    
    -- État de la zone : "available", "depleted", "respawning"
    self.state = state or "available"
    
    -- Villageois actuellement en train de récolter
    self.currentHarvesters = {}  -- {villagerId = { startTime, expectedAmount }}
    
    -- Statistiques
    self.totalHarvested = 0
    self.harvestCount = 0
end

-- Méthodes utilitaires
function TreeZoneComponent:canHarvest()
    return self.state == "available" and self.woodAmount > 0
end

function TreeZoneComponent:isEmpty()
    return self.woodAmount <= 0
end

function TreeZoneComponent:isFull()
    return self.woodAmount >= self.maxWood
end

function TreeZoneComponent:getAvailableWood()
    return self.woodAmount
end

function TreeZoneComponent:startHarvest(villagerId, amount)
    if not self:canHarvest() then
        return false
    end
    
    amount = amount or 1
    amount = math.min(amount, self.woodAmount)
    
    self.currentHarvesters[villagerId] = {
        startTime = love.timer.getTime(),
        expectedAmount = amount
    }
    
    return true
end

function TreeZoneComponent:cancelHarvest(villagerId)
    self.currentHarvesters[villagerId] = nil
end

function TreeZoneComponent:completeHarvest(villagerId)
    local harvest = self.currentHarvesters[villagerId]
    if not harvest then
        return 0
    end
    
    local amount = harvest.expectedAmount
    amount = math.min(amount, self.woodAmount)
    
    self.woodAmount = self.woodAmount - amount
    self.totalHarvested = self.totalHarvested + amount
    self.harvestCount = self.harvestCount + 1
    
    self.currentHarvesters[villagerId] = nil
    
    -- Changer l'état si épuisé
    if self.woodAmount <= 0 then
        self.state = "depleted"
        self.respawnTimer = self.respawnTime
    end
    
    return amount
end

function TreeZoneComponent:update(dt)
    -- Vérifier si épuisement (au cas où woodAmount changé manuellement)
    if self.state == "available" and self.woodAmount <= 0 then
        self.state = "depleted"
        self.respawnTimer = self.respawnTime
        self.currentHarvesters = {}
    end
    
    -- Gestion du respawn
    if self.state == "depleted" then
        self.respawnTimer = self.respawnTimer - dt
        if self.respawnTimer <= 0 then
            self.state = "respawning"
        end
    elseif self.state == "respawning" then
        -- Respawn instantané pour la démo, peut être amélioré avec animation
        self.woodAmount = self.maxWood
        self.state = "available"
        self.currentHarvesters = {}
    end
end

function TreeZoneComponent:isBeingHarvested()
    for _, _ in pairs(self.currentHarvesters) do
        return true
    end
    return false
end

function TreeZoneComponent:getHarvestProgress(villagerId)
    local harvest = self.currentHarvesters[villagerId]
    if not harvest then
        return 0
    end
    
    local elapsed = love.timer.getTime() - harvest.startTime
    local progress = elapsed / self.harvestTime
    return math.min(progress, 1.0)
end

function TreeZoneComponent:isHarvestComplete(villagerId)
    return self:getHarvestProgress(villagerId) >= 1.0
end

return TreeZoneComponent
