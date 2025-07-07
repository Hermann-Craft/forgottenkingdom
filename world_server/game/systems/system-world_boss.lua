local WorldBossSystem = require(_G.libDir .. "middleclass")("WorldBossSystem")

local MonsterEntity = require(_G.entitiesDir .. "entity-monster")

function WorldBossSystem:initialize( world )
    self.world = world

    self.nextWorldBossTimer = 1
    self.currentWorldBossTimer = self.nextWorldBossTimer
    self.worldBossList = { "Mother Spider" }
    self.worldBossDefeated = {}
    self.currentWorldBoss = nil
end

function WorldBossSystem:update(dt)
    if self.currentWorldBossTimer > 0 then
        self.currentWorldBossTimer = self.currentWorldBossTimer - dt
    end

    if self.currentWorldBossTimer < 0 and self.currentWorldBoss == nil and #self.worldBossList > 0 then

        self.currentWorldBoss = self.worldBossList[1] .. "#event"
        local newEntity = MonsterEntity:new(self.worldBossList[1] .. "#event", 100, { x= 400, y = 400})
        newEntity:addTag("worldboss")
        self.world:addEntity(newEntity)
        table.remove(self.worldBossList, 1)
    end

    if self.currentWorldBoss ~= nil then
        local entity = self.world:getEntityById(self.currentWorldBoss)
        if entity == nil then 
            self.currentWorldBoss = nil
            self.currentWorldBossTimer = self.nextWorldBossTimer
        end
    end
end

return WorldBossSystem