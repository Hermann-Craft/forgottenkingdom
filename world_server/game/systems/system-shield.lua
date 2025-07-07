local ShieldSystem = require(_G.libDir .. "middleclass")("ShieldSystem")

function ShieldSystem:initialize( world )
    self.world = world
end

function ShieldSystem:update(dt)
    for i, entity in ipairs(self.world:getEntitiesWithComponent("Player")) do
        local entityPosition = entity:getComponent("Transform")
        local entityShield = entity:getComponent("Shield")

    end
end

return ShieldSystem