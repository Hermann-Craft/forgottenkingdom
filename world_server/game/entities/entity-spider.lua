local Entity = require(_G.engineDir .. "entity")
local SpiderEntity = require(_G.libDir .. "middleclass")("SpiderEntity", Entity)

-- Components
local LifeComponent                 = require(_G.componentsDir .. "component-life")
local TransformComponent            = require(_G.componentsDir .. "component-transform")
local FollowParentEntityComponent   = require(_G.componentsDir .. "component-follow_parent_entity")
local SquareComponent               = require(_G.componentsDir .. "component-square")

function SpiderEntity:initialize( id, life, position, parentEntityId)
    Entity.initialize(self, id)

    self:addComponent(LifeComponent:new(life))
    self:addComponent(TransformComponent:new(position))
    self:addComponent(SquareComponent:new(16,16))
    self:addComponent(FollowParentEntityComponent:new(parentEntityId))
end

function SpiderEntity:update(dt)
    Entity.update(self, dt)
end

return SpiderEntity