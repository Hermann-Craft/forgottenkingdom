local DestroySystem = require(_G.libDir .. "middleclass")("DestroySystem")

local Compositions = require(_G.gameDir .. "compositions")

function DestroySystem:initialize( world )
    self.world = world
end

function DestroySystem:update(dt)
    for i, v in ipairs(self.world.entities) do
        if v.markDestroy == true then
            self.world:removeEntityById(v.id)
        end
    end

    local characters = self.world:getEntitiesWithAtLeast(Compositions.Character)
    for i, char in ipairs(characters) do
        local charLife = char:getComponent("Life")
        if charLife and charLife.life <= 0 then
            for i, v in ipairs(char.attackers) do
                local entity = self.world:getEntityById(v)
                local eClan = entity:getComponent("Clan")
                eClan.clanFame = eClan.clanFame + 1
            end
            self.world:removeEntityById(char.id)
        end
    end
end

return DestroySystem
