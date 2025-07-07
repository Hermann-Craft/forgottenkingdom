local BrainComponent = require(_G.libDir .. "middleclass")("Brain")

BrainComponent.static.name = "Brain"
BrainComponent.static.client = false

function BrainComponent:initialize(tasks)
    self.tasks = tasks or {}
end

return BrainComponent