local PositionComponent = require(_G.libDir .. "middleclass")("Position")

PositionComponent.static.name = "Position"
PositionComponent.static.client = true

function PositionComponent:initialize(position)
    position = position or { x = 0, y = 0 }
    self.origin = { x = position.x, y = position.y }
    self.position = { x = position.x, y = position.y }
end

return PositionComponent
