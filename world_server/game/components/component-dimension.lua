local DimensionComponent = require(_G.libDir .. "middleclass")("Dimension")

DimensionComponent.static.name = "Dimension"
DimensionComponent.static.client = true

function DimensionComponent:initialize( dimension )
    self.width = dimension.width
    self.height = dimension.height
end

return DimensionComponent