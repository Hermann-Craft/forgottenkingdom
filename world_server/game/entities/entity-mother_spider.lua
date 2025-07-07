local Entity = require(_G.engineDir .. "entity")
local MotherSpiderEntity = require(_G.libDir .. "middleclass")("MotherSpiderEntity", Entity)

-- Components
local LifeComponent         = require(_G.componentsDir .. "component-life")
local TransformComponent    = require(_G.componentsDir .. "component-transform")
local MotherComponent       = require(_G.componentsDir .. "component-mother")
local SquareComponent       = require(_G.componentsDir .. "component-square")
local AttackPlayerComponent = require(_G.componentsDir .. "component-attack_player")

function MotherSpiderEntity:initialize( id, life, position )
    Entity.initialize(self, id)

    self:addComponent(LifeComponent:new(life))
    self:addComponent(TransformComponent:new(position))
    self:addComponent(SquareComponent:new(32,32))
    self:addComponent(MotherComponent:new("spider", 10, 300))
    self:addComponent(AttackPlayerComponent:new())
end

function MotherSpiderEntity:update(dt)
    Entity.update(self, dt)
end

return MotherSpiderEntity