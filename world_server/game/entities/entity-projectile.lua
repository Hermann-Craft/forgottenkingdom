local Entity = require(_G.engineDir .. "entity")
local ProjectileEntity = require(_G.libDir .. "middleclass")("ProjectileEntity", Entity)

-- Components
local Components            = require(_G.componentsDir .. "components")

function ProjectileEntity:initialize( id, position, orientation, dimension, speed, force, distance, ownerId)
    self.origin = {
        x = position.x,
        y = position.y
    }
    Entity.initialize(self, id, {
        Components.Position:new(position),
        Components.Orientation:new(orientation),
        Components.Dimension:new(dimension),
        Components.Speed:new(speed),
        Components.Force:new(force),
        Components.Distance:new(distance),
        Components.Owner:new(ownerId)
    })
end

return ProjectileEntity