local QuestComponent = require(_G.libDir .. "middleclass")("Quest")

QuestComponent.static.name = "Quest"
QuestComponent.static.client = true

function QuestComponent:initialize(quests)
    self.quests = quests or nil
end

return QuestComponent
