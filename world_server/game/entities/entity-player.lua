local Entity = require(_G.engineDir .. "entity")
local PlayerEntity = require(_G.libDir .. "middleclass")("PlayerEntity", Entity)

-- Components
local Components            = require(_G.componentsDir .. "components")

local ProjectileEntity = require(_G.entitiesDir .. "entity-projectile")

function PlayerEntity:initialize( id, data)
    Entity.initialize(self, id, {
        Components.Grade:new( data.grade or 1),
        Components.Position:new( data.position),
        Components.Orientation:new( data.orientation ),
        Components.Dimension:new( data.dimension ),
        Components.Hand:new( data.hand ),
        Components.Eye:new( data.viewDistance ),
        Components.Intelligence:new( data.intelligence ),
        Components.Force:new( data.force ),
        Components.Speed:new( data.speed ),
        Components.Agility:new( data.agility ),
        Components.Life:new( data.life ),
        Components.Fame:new( data.fame ),
        Components.Shield:new( data.shield ),
        Components.Wallet:new( data.wallet ),
        Components.Clan:new( data.clan.name, data.clan.fame ),
        Components.Player:new(),
        Components.Quest:new( data.quest ),
        Components.Name:new( data.name ),
        Components.Texture:new( data.texture)
    })
    self.shootInterval = 0
    self.attackers = {}
end

function PlayerEntity:update(dt)
    Entity.update(self, dt)
    self.shootInterval = self.shootInterval - dt
end

function PlayerEntity:shoot()
    if self.shootInterval <= 0 then
        local position = self:getComponent("Position").position
        local force = self:getComponent("Force").force
        local orientation = self:getComponent("Orientation").orientation
        _G.RealmWorld:addEntity(ProjectileEntity:new(uuid(), { x = position.x, y = position.y }, orientation, { width = 8, height = 8 }, 50, force, 400, self.id))
        self.shootInterval = 0.3
    end
end

return PlayerEntity
