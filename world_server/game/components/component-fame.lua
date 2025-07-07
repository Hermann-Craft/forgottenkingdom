local FameComponent = require(_G.libDir .. "middleclass")("Fame")

FameComponent.static.name = "Fame"
FameComponent.static.client = true

function FameComponent:initialize(fame)
    self.fame = fame
end

return FameComponent