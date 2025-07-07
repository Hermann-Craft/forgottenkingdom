local MotherSystem = require(_G.libDir .. "middleclass")("MotherSystem")

local random = math.random
local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

local SpiderEntity = require(_G.entitiesDir .. "entity-spider")

function MotherSystem:initialize( world )
    self.world = world
end

function MotherSystem:update(dt)
    local motherEntities = self.world:getEntitiesWithAtLeast({"Transform", "Mother"})
    for i, v in ipairs(motherEntities) do
        local motherComponent = v:getComponent("Mother")
        local transformComponent = v:getComponent("Transform")
        if #motherComponent.childs < motherComponent.maxChild then
            -- Entity.create("entityName", { })
            local newEntity = SpiderEntity:new(uuid(), 100, { x=random(transformComponent.position.x - 32, transformComponent.position.x + 32), y = random(transformComponent.position.y - 32, transformComponent.position.y + 32) }, v.id)
            self.world:addEntity(newEntity)
            table.insert(motherComponent.childs, #motherComponent.childs + 1, newEntity.id)
        end
    end
end

return MotherSystem