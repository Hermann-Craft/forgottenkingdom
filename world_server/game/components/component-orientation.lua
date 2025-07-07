local OrientationComponent = require(_G.libDir .. "middleclass")("Orientation")

OrientationComponent.static.name = "Orientation"
OrientationComponent.static.client = true

function OrientationComponent:initialize(orientation)
    self.orientation = orientation
end

return OrientationComponent