local DeathSystem = require(_G.libDir .. "middleclass")("DeathSystem")

function DeathSystem:initialize( world )
    self.world = world
end

function DeathSystem:update(dt)
    local entitiesWithLife = self.world:getEntitiesWithComponent("Life")
    for i, v in ipairs(entitiesWithLife) do
        if v:getComponent("Life").life <= 0 then
            print("dzdaz")
            self.world:removeEntityById(v.id)
        end
    end
end

return DeathSystem