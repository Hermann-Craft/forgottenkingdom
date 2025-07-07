local NameComponent = require(_G.libDir .. "middleclass")("Name")

NameComponent.static.name = "Name"
NameComponent.static.client = true

function NameComponent:initialize(name)
    self.name = name
end

return NameComponent