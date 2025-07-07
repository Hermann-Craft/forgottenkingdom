local Entity = require(_G.engineDir .. "entity")
local CharacterEntity = require(_G.libDir .. "middleclass")("CharacterEntity", Entity)

-- Components
local Components            = require(_G.componentsDir .. "components")

function CharacterEntity:initialize( id, data)
    Entity.initialize(self, id, {
        Components.Position:new( data.position ),
        Components.Orientation:new( data.orientation ),
        Components.Dimension:new( data.dimension ),
        Components.Hand:new( data.hand ),
        Components.Eye:new( data.eye ),
        Components.Brain:new({ "CanAttackEnemyClan" }),
        Components.Intelligence:new( data.intelligence ),
        Components.Force:new( data.force ),
        Components.Speed:new( data.speed ),
        Components.Agility:new( data.agility ),
        Components.Energy:new( data.energy ),
        Components.Life:new( data.life ),
        Components.Fame:new( data.fame ),
        Components.Wallet:new( data.wallet ),
        Components.Clan:new( data.clan ),
        Components.Quest:new( data.quest ),
        Components.Name:new( data.name )
    })

    self.attackers = {}
end

return CharacterEntity