local World = require(_G.libDir .. "middleclass")("World")
local Serializer = require(_G.libDir .. "serializer")

function World:initialize ()
    self.entities = {}
    self.systems = {}
end

function World:update(dt)
    for i, v in ipairs(self.entities) do
        if v.update ~= nil then
            v:update(dt)
        end
    end

    for i, v in ipairs(self.systems) do
        v:update(dt)
    end

    _G.Server.Udp:send(_G.bitser.dumps({
        id = "world_update",
        worldData = self:toNbt()
    }))
end

function World:addEntity( entity )
    table.insert(self.entities, #self.entities + 1, entity)
    _G.Server.Udp:send(_G.bitser.dumps({
        id = "entity_create",
        entityData = entity:toNbt()
    }))
end

function World:getEntitiesWithComponent( componentName )
    local entities = {}
    
    for i, v in ipairs(self.entities) do
        if v:getComponent(componentName) then
            table.insert(entities, #entities + 1, self.entities[i])
        end
    end

    return entities
end

function World:getEntitiesByTag(tag)
    local entities = {}
    
    for i, v in ipairs(self.entities) do
        for it, vt in ipairs(v.tags) do
            if vt == tag then
                table.insert(entities, #entities + 1, v)
            end
        end
    end

    return entities

end

function findElement(list, element)
    local found = false

    for i, v in ipairs(list) do
        if v == element then
            found = true
        end
    end
    
    return found
end

function findElementInIndexList(list, elements)
    local found = false
    local foundElements = {}

    for i, v in ipairs(list) do
        for ie, ve in ipairs(elements) do
            if not findElement(foundElements, ve) and ve == v then
                table.insert(foundElements, #foundElements + 1, ve)
            end
        end
    end
    
    if #elements == #foundElements then
        return true
    else
        return false
    end
end

function getComponentListName (components)
    local componentNames = {}
    for i, v in ipairs(components) do
        table.insert(componentNames, #componentNames + 1, v.class.name)
    end
    return componentNames
end

function World:getEntitiesWithAtLeast( checkList )
    local entities = {}
    for i, entity in ipairs(self.entities) do
        local have = true
        for i, check in ipairs(checkList) do
            local found = false

            for i, component in ipairs(entity.components) do
                if component.class.name == check then
                    found = true
                    break
                end
            end
            
            if not found then
                have = false
                break
            end
        end

        -- if the entity have the components designed in the check list
        if have then
            table.insert(entities, #entities + 1, entity)
        end
    end
    return entities
end

function World:getEntitiesWithStrict( checkList )
    local entities = {}
    
    for i, entity in ipairs(self.entities) do
        -- [check] if the entity have the components designed in the check list
        local have = true
        for i, check in ipairs(checkList) do
            local found = false

            for i, component in ipairs(entity.components) do
                if component.class.name == check then
                    found = true
                    break
                end
            end
            
            if not found then
                have = false
                break
            end
        end

        -- if the entity have the components designed in the check list
        if have then
            -- [check] if the entity have the strict number of component of the checklist 
            if #entity.components == #checkList then
                table.insert(entities, #entities + 1, entity)
            end
        end
    end

    return entities
end

function World:getEntitiesWithTags (tags)
    local entities = {}
    
    for i, v in ipairs(self.entities) do
        if findElementInIndexList(v.tags, tags) then
            table.insert(entities, #entities + 1, v)
        end
    end

    return entities
end

function World:getEntityById( entityId )
    local index = nil

    for i, v in ipairs(self.entities) do
        if v.id == entityId then
            index = i
        end
    end

    return self.entities[index]
end

function World:removeEntityById( entityId )
    local index = nil

    for i, v in ipairs(self.entities) do
        if v.id == entityId then
            index = i
        end
    end

    if index ~= nil then
        _G.Server.Udp:send(_G.bitser.dumps({
            id = "entity_remove",
            entityId = entityId
        }))
        table.remove(self.entities, index)
    end
end

function World:addSystem(system)
    table.insert(self.systems, #self.systems + 1, system);
end


function World:toNbt()
    local toNbt = {}
    toNbt.width = self.width
    toNbt.height = self.height
    toNbt.entities = {}
    for i, entity in ipairs(self.entities) do
        table.insert(toNbt.entities, #toNbt.entities + 1, entity:toNbt())
    end
    return toNbt
end

return World
