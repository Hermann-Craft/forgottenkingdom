local OwnerComponent = require(_G.libDir .. "middleclass")("Owner")

OwnerComponent.static.name = "Owner"
OwnerComponent.static.client = false

function OwnerComponent:initialize(ownerId)
    self.ownerId = ownerId
end

return OwnerComponent