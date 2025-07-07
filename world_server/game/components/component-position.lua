local PositionComponent = require(_G.libDir .. "middleclass")("Position")

PositionComponent.static.name = "Position"
PositionComponent.static.client = true

function PositionComponent:initialize(position)
    local position = { x = position.x, y = position.y }
    self.origin = position or { x = 0, y = 0 }
    self.position = position or { x = 0, y = 0 }
end

return PositionComponent
