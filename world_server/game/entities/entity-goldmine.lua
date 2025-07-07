local Entity = require(_G.engineDir .. "entity")
local GoldMineEntity = require(_G.libDir .. "middleclass")("GoldMineEntity", Entity)

-- Components
local Components = require(_G.componentsDir .. "components")

function GoldMineEntity:initialize(id, position, goldAmount, maxGold)
    Entity.initialize(self, id, {
        Components.Position:new(position),
        Components.Orientation:new(0), -- Mines n'ont pas d'orientation
        Components.Dimension:new({ width = 64, height = 64 }),
        Components.Resources:new(goldAmount, maxGold, 300), -- 5 minutes de respawn
        Components.Name:new("Mine d'Or"),
        Components.Texture:new({
            name = "goldmine",
            index = 1,
            size = 64
        })
    })
end

function GoldMineEntity:update(dt)
    Entity.update(self, dt)
    
    -- Mise à jour du composant Resources
    local resources = self:getComponent("Resources")
    if resources then
        resources:update(dt)
    end
end

function GoldMineEntity:canBeHarvested()
    local resources = self:getComponent("Resources")
    return resources and resources:canHarvest()
end

function GoldMineEntity:harvest(amount)
    local resources = self:getComponent("Resources")
    if resources then
        return resources:harvest(amount)
    end
    return 0
end

function GoldMineEntity:getResourceState()
    local resources = self:getComponent("Resources")
    if resources then
        return {
            goldAmount = resources.goldAmount,
            maxGold = resources.maxGold,
            state = resources.state,
            respawnTimer = resources.respawnTimer
        }
    end
    return nil
end

return GoldMineEntity 
