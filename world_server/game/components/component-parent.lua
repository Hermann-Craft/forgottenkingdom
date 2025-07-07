local MotherComponent = require(_G.libDir .. "middleclass")("Mother")

MotherComponent.static.name = "Mother"
MotherComponent.static.client = false

function MotherComponent:initialize(childName, maxChild, spawnInterval)
    self.childName = childName
    self.maxChild = maxChild
    self.spawnInterval = spawnInterval
    self.childs = {}
end

return MotherComponent