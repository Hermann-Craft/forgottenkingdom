local SpeedComponent = require(_G.libDir .. "middleclass")("Speed")

SpeedComponent.static.name = "Speed"
SpeedComponent.static.client = false

function SpeedComponent:initialize(speed)
    self.speed = speed
    self.maxSpeed = speed or 0
end

return SpeedComponent