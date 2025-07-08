local Target = require(_G.libDir .. "middleclass")("Target")

function Target:initialize(targetId, distance)
    self.id = targetId or nil  -- ID de l'entité ciblée (joueur, ressource, etc.)
    self.distance = distance or 0  -- Distance jusqu'à la cible
    
    -- Nouvelles propriétés pour l'IA de mouvement
    self.destination = nil  -- Position de destination { x, y }
    self.isMoving = false   -- Indique si l'entité est en mouvement
end

Target.static.client = true

return Target 
