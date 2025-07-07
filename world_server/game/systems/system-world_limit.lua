local WorldLimitSystem = require(_G.libDir .. "middleclass")("WorldLimitSystem")
local Compositions = require(_G.gameDir .. "compositions")

function WorldLimitSystem:initialize( world )
    self.world = world
end

function WorldLimitSystem:update(dt)
    local playerEntities = self.world:getEntitiesWithStrict(Compositions.Player)
    for i, v in ipairs(playerEntities) do
        local vPos = v:getComponent("Position").position
        if vPos.x < 0 or vPos.x > self.world.width or vPos.y > self.world.height or vPos.y < 0 then
            v:getComponent("Position").position.x = love.math.random(0, 2000)
            v:getComponent("Position").position.y = love.math.random(0, 2000)
        end
    end
end

return WorldLimitSystem
