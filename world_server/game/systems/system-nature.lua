local NatureSystem = require(_G.libDir .. "middleclass")("NatureSystem")

local random = math.random
local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and love.math.random(0, 0xf) or love.math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

local Compositions = require(_G.gameDir .. "compositions")
local CharacterEntity = require(_G.entitiesDir .. "entity-character")

function NatureSystem:initialize( world )
    self.world = world
    self.limitOfMonster = 10
end

function NatureSystem:update(dt)
    local characters = self.world:getEntitiesWithAtLeast(Compositions.Character)

    if #characters < self.limitOfMonster then
        for k, v in pairs(_G.DB.Entities) do
            if v.name == "Mother Spider" then
                local motherSpider = CharacterEntity:new(uuid(), v)
                local cPos = motherSpider:getComponent("Position")
                cPos.position.x = love.math.random(0, self.world.width)
                cPos.position.y = love.math.random(0, self.world.height)
                self.world:addEntity(motherSpider)
            end
        end
    end
end

return NatureSystem