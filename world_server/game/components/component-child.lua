local ChildComponent = require(_G.libDir .. "middleclass")("Child")

ChildComponent.static.name = "Child"
ChildComponent.static.client = false

function ChildComponent:initialize(parentId)
    self.parentId = parentId
end

return ChildComponent