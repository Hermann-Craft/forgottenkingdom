local Entity = require(_G.engineDir .. "entity")
local VillagerEntity = require(_G.libDir .. "middleclass")("VillagerEntity", Entity)

-- Components
local Components = require(_G.componentsDir .. "components")
local TaskEnum = require(_G.gameDir .. "task-enum")

function VillagerEntity:initialize(id, data)
    Entity.initialize(self, id, {
        Components.Position:new(data.position),
        Components.Orientation:new(data.orientation or 0),
        Components.Dimension:new(data.dimension or { width = 32, height = 32 }),
        Components.Speed:new(data.speed or 50),
        Components.Life:new(data.life or 100),
        Components.Name:new(data.name or "Villageois"),
        Components.Texture:new(data.texture or { name = "villager", index = 1, size = 32 }),
        
        -- Composants spécifiques aux villageois (Phase 1-5)
        Components.Villager:new(),
        Components.Hireable:new(),  -- Recrutables par défaut
        Components.Brain:new({}, TaskEnum.Idle),  -- Tâche par défaut : Idle
        Components.Target:new(),    -- Pas de cible initiale
        Components.Resource:new()   -- Inventaire de ressources (Phase 5)
    })
    
    -- Clan sera ajouté lors du recrutement
    -- Worker remplacera Hireable lors du recrutement
end

function VillagerEntity:update(dt)
    Entity.update(self, dt)
    -- Logique spécifique aux villageois sera ajoutée dans les systèmes
end

-- Méthode pour être recruté par un joueur
function VillagerEntity:recruit(playerClan)
    -- Retirer le tag Hireable
    for i, component in ipairs(self.components) do
        if component.class.name == "Hireable" then
            table.remove(self.components, i)
            break
        end
    end
    
    -- Ajouter Worker et Clan
    self:addComponent(Components.Worker:new())
    self:addComponent(Components.Clan:new(playerClan.name, playerClan.fame or 0))
    
    -- Changer la tâche par défaut en Follow
    local brain = self:getComponent("Brain")
    if brain then
        brain.task = TaskEnum.Follow
    end
end

return VillagerEntity 
