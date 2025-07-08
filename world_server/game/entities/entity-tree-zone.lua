local Entity = require(_G.libDir .. "engine.entity")
local Components = require(_G.componentsDir .. "components")

local TreeZoneEntity = Entity:subclass("TreeZoneEntity")

function TreeZoneEntity:initialize(id, position, config)
    position = position or { x = 0, y = 0 }
    config = config or {}
    
    -- Configuration par défaut
    local defaultConfig = {
        woodAmount = 20,
        maxWood = 20,
        harvestTime = 3,
        respawnTime = 60,
        name = "Zone d'arbres",
        texture = { name = "tree_zone", index = 1, size = { width = 80, height = 80 } },
        dimension = { width = 80, height = 80 }
    }
    
    -- Merge avec la config fournie
    for key, value in pairs(config) do
        defaultConfig[key] = value
    end
    
    -- Initialisation des composants réels (pas des données brutes)
    Entity.initialize(self, id, {
        Components.Position:new({ x = position.x, y = position.y }),
        Components.Orientation:new(0),
        Components.Dimension:new(defaultConfig.dimension),
        Components.TreeZone:new(
            defaultConfig.woodAmount,
            defaultConfig.maxWood,
            defaultConfig.respawnTime,
            defaultConfig.harvestTime,
            "available"
        ),
        Components.Name:new(defaultConfig.name),
        Components.Texture:new(defaultConfig.texture)
    })
end

-- Méthodes utilitaires
function TreeZoneEntity:getWoodAmount()
    local treeZone = self:getComponent("TreeZone")
    return treeZone and treeZone.woodAmount or 0
end

function TreeZoneEntity:canHarvest()
    local treeZone = self:getComponent("TreeZone")
    return treeZone and treeZone:canHarvest() or false
end

function TreeZoneEntity:startHarvest(villagerId, amount)
    local treeZone = self:getComponent("TreeZone")
    return treeZone and treeZone:startHarvest(villagerId, amount) or false
end

function TreeZoneEntity:completeHarvest(villagerId)
    local treeZone = self:getComponent("TreeZone")
    return treeZone and treeZone:completeHarvest(villagerId) or 0
end

function TreeZoneEntity:cancelHarvest(villagerId)
    local treeZone = self:getComponent("TreeZone")
    if treeZone then
        treeZone:cancelHarvest(villagerId)
    end
end

function TreeZoneEntity:isHarvestComplete(villagerId)
    local treeZone = self:getComponent("TreeZone")
    return treeZone and treeZone:isHarvestComplete(villagerId) or false
end

function TreeZoneEntity:getState()
    local treeZone = self:getComponent("TreeZone")
    return treeZone and treeZone.state or "unknown"
end

function TreeZoneEntity:getHarvestStats()
    local treeZone = self:getComponent("TreeZone")
    if not treeZone then
        return { woodAmount = 0, maxWood = 0, state = "unknown", totalHarvested = 0 }
    end
    
    return {
        woodAmount = treeZone.woodAmount,
        maxWood = treeZone.maxWood,
        state = treeZone.state,
        totalHarvested = treeZone.totalHarvested,
        harvestCount = treeZone.harvestCount,
        currentHarvesters = {}  -- Ne pas exposer les détails internes
    }
end

return TreeZoneEntity 
