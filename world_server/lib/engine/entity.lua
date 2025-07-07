local Entity = require(_G.libDir .. "middleclass")("Entity")
local Serializer = require(_G.libDir .. "serializer")

function Entity:initialize(id, components)
    self.id = id
    self.tags = {}
    self.components = components or {}
end

function Entity:sendCreate()
    _G.Server.Tcp:send(_G.bitser.dumps({
        id = "entity_create",
        entityData = self:toNbt()
    }))
end

function Entity:sendUpdate()
    _G.Server.Udp:send(_G.bitser.dumps({
        id = "entity_update",
        entityId = self.id,
        entityData = self:toNbt()
    }))
end

function Entity:addTag (tag)
    local foundTag = false
    
    for i, v in ipairs(self.tags) do
        if v == tag then
            foundTag = true
        end
    end
    
    if foundTag ~= true then
        table.insert(self.tags, #self.tags + 1, tag)
    end
end

function Entity:getTag(tag)
    local foundTag = nil
    
    for i, v in ipairs(self.tags) do
        if v == tag then
            foundTag = v
        end
    end

    return foundTag
end

function Entity:getComponent( componentName )
    local component = nil
    for i, v in ipairs(self.components) do
        if v.class.name == componentName then
            component = self.components[i]
        end
    end
    return component
end

function Entity:getComposition()
    local composition = {}
    for i, v in ipairs(self.components) do
        table.insert(composition, #composition + 1, v.class.name)
    end
    return composition
end

function Entity:addComponent( component )
    table.insert(self.components, #self.components + 1, component)
end

function Entity:update(dt)
    for i, v in ipairs(self.components) do
        if type(v.update) == "function" then
            v:update(dt)
        end
    end
    _G.Server.Udp:send(_G.bitser.dumps({
        id = "entity_update",
        entityId = self.id,
        entityData = self:toNbt()
    }))
end

function Entity:toNbt()
    local toNbt = {}
    toNbt.id = self.id
    toNbt.components = {}
    for i, component in ipairs(self.components) do
        if component.class.client then
            local cmpt = {}
            for k, v in pairs(component) do    
                if k ~= "class" and type(v) ~= "function" then
                    cmpt[k] = v
                end
            end
            toNbt.components[component.class.name] = cmpt
        end
    end
    return toNbt
end

return Entity
