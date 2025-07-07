local ResourcesComponent = require(_G.libDir .. "middleclass")("Resources")

ResourcesComponent.static.name = "Resources"
ResourcesComponent.static.client = true

function ResourcesComponent:initialize(goldAmount, maxGold, respawnDelay)
    self.goldAmount = goldAmount or 100
    self.maxGold = maxGold or 100
    self.respawnTimer = 0
    self.respawnDelay = respawnDelay or 300 -- 5 minutes en secondes
    self.state = "full" -- "full", "partial", "empty", "respawning"
    self.lastHarvest = 0 -- Temps du dernier harvest pour cooldown
    self.harvestCooldown = 2 -- 2 secondes entre chaque récolte
end

function ResourcesComponent:update(dt)
    -- Mise à jour du timer de respawn
    if self.state == "respawning" and self.respawnTimer > 0 then
        self.respawnTimer = self.respawnTimer - dt
        if self.respawnTimer <= 0 then
            self.goldAmount = self.maxGold
            self.state = "full"
        end
    end
    
    -- Mise à jour de l'état basé sur la quantité d'or
    if self.goldAmount >= self.maxGold * 0.75 then
        self.state = "full"
    elseif self.goldAmount >= self.maxGold * 0.25 then
        self.state = "partial"
    elseif self.goldAmount > 0 then
        self.state = "low"
    else
        if self.state ~= "respawning" then
            self.state = "respawning"
            self.respawnTimer = self.respawnDelay
        end
    end
    
    -- Mise à jour du cooldown de harvest
    if self.lastHarvest > 0 then
        self.lastHarvest = self.lastHarvest - dt
        if self.lastHarvest < 0 then
            self.lastHarvest = 0
        end
    end
end

function ResourcesComponent:canHarvest()
    return self.goldAmount > 0 and self.lastHarvest <= 0
end

function ResourcesComponent:harvest(amount)
    if not self:canHarvest() then
        return 0
    end
    
    local harvestedAmount = math.min(amount, self.goldAmount)
    self.goldAmount = self.goldAmount - harvestedAmount
    self.lastHarvest = self.harvestCooldown
    
    return harvestedAmount
end

return ResourcesComponent 
