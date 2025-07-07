local PlayerComponent = require(_G.libDir .. "middleclass")("Player")

PlayerComponent.static.name = "Player"
PlayerComponent.static.client = true

function PlayerComponent:initialize()
    self.isPlayer = true
    self.pvp = false
end

return PlayerComponent