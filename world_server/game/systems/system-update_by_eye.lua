local UpdateByEyeSystem = require(_G.libDir .. "middleclass")("UpdateByEyeSystem")
local Serializer = require(_G.libDir .. "serializer")

local Compositions = require(_G.gameDir .. "compositions")

function UpdateByEyeSystem:initialize( world )
    self.world = world
end

function UpdateByEyeSystem:update(dt)
    local players = self.world:getEntitiesWithStrict(Compositions.Player)
    for i, v in ipairs(players) do
        local pEye = v:getComponent("Eye")
        local pPos = v:getComponent("Position").position
        for i, entity in ipairs(self.world.entities) do
            local ePos = entity:getComponent("Position").position
            if ePos.x > pPos.x - pEye.viewDistance and ePos.x < pPos.x + pEye.viewDistance and ePos.y > pPos.y - pEye.viewDistance and ePos.y < pPos.y + pEye.viewDistance then
                _G.Server.Udp:send(_G.bitser.dumps({
                    id = "entity_update",
                    entityId = entity.id,
                    entityData = entity:toNbt()
                }))
            end
        end
    end
end

return UpdateByEyeSystem
