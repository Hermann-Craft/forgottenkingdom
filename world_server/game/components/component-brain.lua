local BrainComponent = require(_G.libDir .. "middleclass")("Brain")
local TaskEnum = require(_G.gameDir .. "task-enum")

BrainComponent.static.name = "Brain"
BrainComponent.static.client = false

function BrainComponent:initialize(tasks, task)
    self.tasks = tasks or {}  -- Existant : pour les entités complexes
    self.task = task or TaskEnum.Idle  -- Nouveau : tâche courante du villageois
    self.menuOpen = false  -- Flag pour geler le villageois quand son menu est ouvert
end

-- Exporter TaskEnum pour les autres modules
BrainComponent.TaskEnum = TaskEnum

return BrainComponent
