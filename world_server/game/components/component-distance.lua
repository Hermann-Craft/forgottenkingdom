local DistanceComponent = require(_G.libDir .. "middleclass")("Distance")

DistanceComponent.static.name = "Distance"
DistanceComponent.static.client = false

function DistanceComponent:initialize(distance)
    self.distance = distance
end

return DistanceComponent