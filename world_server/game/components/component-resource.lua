local ResourceComponent = require(_G.libDir .. "middleclass")("Resource")

ResourceComponent.static.name = "Resource"
ResourceComponent.static.client = true  -- Visible côté client pour l'interface

function ResourceComponent:initialize(wood, gold, maxWood, maxGold)
    -- Ressources portées par le villageois
    self.wood = wood or 0
    self.gold = gold or 0
    
    -- Capacité maximale de transport
    self.maxWood = maxWood or 10
    self.maxGold = maxGold or 5
    
    -- État de transport
    self.isCarrying = false
    self.targetResource = nil  -- Type de ressource à récolter ("wood" ou "gold")
end

-- Méthodes utilitaires
function ResourceComponent:canCarryWood(amount)
    amount = amount or 1
    return self.wood + amount <= self.maxWood
end

function ResourceComponent:canCarryGold(amount)
    amount = amount or 1
    return self.gold + amount <= self.maxGold
end

function ResourceComponent:addWood(amount)
    amount = amount or 1
    local actualAmount = math.min(amount, self.maxWood - self.wood)
    self.wood = self.wood + actualAmount
    self.isCarrying = self.wood > 0 or self.gold > 0
    return actualAmount
end

function ResourceComponent:addGold(amount)
    amount = amount or 1
    local actualAmount = math.min(amount, self.maxGold - self.gold)
    self.gold = self.gold + actualAmount
    self.isCarrying = self.wood > 0 or self.gold > 0
    return actualAmount
end

function ResourceComponent:removeWood(amount)
    amount = amount or self.wood
    local actualAmount = math.min(amount, self.wood)
    self.wood = self.wood - actualAmount
    self.isCarrying = self.wood > 0 or self.gold > 0
    return actualAmount
end

function ResourceComponent:removeGold(amount)
    amount = amount or self.gold
    local actualAmount = math.min(amount, self.gold)
    self.gold = self.gold - actualAmount
    self.isCarrying = self.wood > 0 or self.gold > 0
    return actualAmount
end

function ResourceComponent:isEmpty()
    return self.wood == 0 and self.gold == 0
end

function ResourceComponent:isFull()
    return self.wood >= self.maxWood and self.gold >= self.maxGold
end

function ResourceComponent:getCapacityWood()
    return self.maxWood - self.wood
end

function ResourceComponent:getCapacityGold()
    return self.maxGold - self.gold
end

function ResourceComponent:clear()
    self.wood = 0
    self.gold = 0
    self.isCarrying = false
    self.targetResource = nil
end

return ResourceComponent 
