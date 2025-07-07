local ForceComponent = require(_G.libDir .. "middleclass")("Force")

ForceComponent.static.name = "Force"
ForceComponent.static.client = false

function ForceComponent:initialize(force)
    self.force = force or 10
    self.maxForce = force or 10
end

return ForceComponent