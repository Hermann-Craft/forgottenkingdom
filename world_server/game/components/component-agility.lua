local AgilityComponent = require(_G.libDir .. "middleclass")("Agility")

AgilityComponent.static.name = "Agility"
AgilityComponent.static.client = false

function AgilityComponent:initialize(agility)
    self.agility = 0
    self.maxAgility = agility or 0
end

return AgilityComponent