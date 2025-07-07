local LifeComponent = require(_G.libDir .. "middleclass")("Life")

LifeComponent.static.name = "Life"
LifeComponent.static.client = true

function LifeComponent:initialize(life)
    self.life = life or 100
    self.maxLife = life or 100
end

return LifeComponent