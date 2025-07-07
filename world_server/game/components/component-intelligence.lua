local IntelligenceComponent = require(_G.libDir .. "middleclass")("Intelligence")

IntelligenceComponent.static.name = "Intelligence"
IntelligenceComponent.static.client = false

function IntelligenceComponent:initialize(intelligence)
    self.intelligence = 0
    self.maxIntelligence = intelligence or 0
end

return IntelligenceComponent