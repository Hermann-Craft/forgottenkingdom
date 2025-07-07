local Entity = require(_G.engineDir .. "entity")
local MonsterEntity = require(_G.libDir .. "middleclass")("MonsterEntity", Entity)

-- Components
local LifeComponent         = require(_G.componentsDir .. "component-life")
local TransformComponent    = require(_G.componentsDir .. "component-transform")

function MonsterEntity:initialize( id, life, position )
    Entity.initialize(self, id)

    self:addComponent(LifeComponent:new(life))
    self:addComponent(TransformComponent:new(position))
end

function MonsterEntity:update(dt)
    Entity.update(self, dt)
end

return MonsterEntity