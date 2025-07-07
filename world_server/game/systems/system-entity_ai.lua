local EntityAiSystem = require(_G.libDir .. "middleclass")("EntityAiSystem")

function EntityAiSystem:initialize( world )
    self.world = world
end

function EntityAiSystem:update(dt)
    local monsterEntities = self.world:getEntitiesWithAtLeast({"Transform", "AttackPlayer"})
    local playerEntities = self.world:getEntitiesWithComponent("Player");
    for i, v in ipairs(monsterEntities) do
        local enemyTransform = v:getComponent("Transform").position
        for ip, vp in ipairs(playerEntities) do
            local vpTransform = vp:getComponent("Transform").position
            if vpTransform.x > enemyTransform.x - 200 and vpTransform.x < enemyTransform.x + 200 and vpTransform.y > enemyTransform.y - 200 and vpTransform.y < enemyTransform.y + 200 then
                local velx = math.cos(math.atan2(enemyTransform.y - vpTransform.y, enemyTransform.x - vpTransform.x))
                local vely = math.sin(math.atan2(enemyTransform.y - vpTransform.y, enemyTransform.x - vpTransform.x));

                enemyTransform.x = enemyTransform.x - velx * (10 * dt)
                enemyTransform.y = enemyTransform.y - vely * (10 * dt)
            end
        end
    end
end

return EntityAiSystem