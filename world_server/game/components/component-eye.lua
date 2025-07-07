local EyeComponent = require(_G.libDir .. "middleclass")("Eye")

EyeComponent.static.name = "Eye"
EyeComponent.static.client = true

function EyeComponent:initialize(viewDistance)
    self.viewDistance = viewDistance or nil
end

return EyeComponent