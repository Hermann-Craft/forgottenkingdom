local Entity = require(_G.libDir .. "middleclass")("Entity")
local Serializer = require(_G.libDir .. "serializer")

function Entity:initialize(id, components)
    self.id = id
    self.tags = {}
    self.components = components or {}
    
    -- OPTIMISATION: Système de changements pour éviter les envois inutiles
    self.lastSentData = nil
    self.lastUpdateTime = 0
    self.isDirty = true  -- CORRECTION: Nouvelles entités sont dirty par défaut !
    self.updateFrequency = 0.1  -- Envoyer max 10 fois par seconde
    self.isNewEntity = true  -- Flag pour forcer le premier envoi
    
    -- OPTION DEBUG: Désactiver l'optimisation pour cette entité
    self.disableOptimization = _G.DISABLE_ENTITY_OPTIMIZATION or false
    
    -- Données critiques qui nécessitent envoi immédiat
    self.criticalComponents = {
        "Position", "Health", "Resources", "Wallet", "Brain"
    }
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
    -- DEBUG: Si optimisation désactivée, utiliser l'ancien système
    if self.disableOptimization then
        for i, v in ipairs(self.components) do
            if type(v.update) == "function" then
                v:update(dt)
            end
        end
        self:sendUpdate()  -- Envoi direct comme avant
        return
    end
    
    local hasChanged = false
    
    -- Mettre à jour les composants et détecter les changements
    for i, v in ipairs(self.components) do
        if type(v.update) == "function" then
            -- Sauvegarder l'état avant mise à jour pour les composants critiques
            local oldState = nil
            if self:isCriticalComponent(v.class.name) then
                oldState = self:serializeComponent(v)
            end
            
            v:update(dt)
            
            -- Vérifier si un composant critique a changé
            if oldState then
                local newState = self:serializeComponent(v)
                if oldState ~= newState then
                    hasChanged = true
                    self.isDirty = true
                end
            end
        end
    end
    
    -- CORRECTION: Forcer l'envoi immédiat pour les nouvelles entités
    local currentTime = love.timer.getTime()
    if self.isNewEntity then
        -- Envoyer immédiatement les nouvelles entités sans throttling
        self:sendUpdateToNearbyClients()
        self.lastUpdateTime = currentTime
        self.isDirty = false
        self.isNewEntity = false  -- Plus nouveau après le premier envoi
        return
    end
    
    -- OPTIMISATION: N'envoyer que si nécessaire et pas trop fréquemment
    if self.isDirty and (currentTime - self.lastUpdateTime) >= self.updateFrequency then
        self:sendUpdateToNearbyClients()
        self.lastUpdateTime = currentTime
        self.isDirty = false
    end
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

-- OPTIMISATIONS NOUVELLES MÉTHODES

-- Vérifier si un composant est critique (nécessite mise à jour rapide)
function Entity:isCriticalComponent(componentName)
    for _, criticalName in ipairs(self.criticalComponents) do
        if componentName == criticalName then
            return true
        end
    end
    return false
end

-- Sérialiser un composant pour détecter les changements
function Entity:serializeComponent(component)
    if not component then return "" end
    
    if component.class.name == "Position" then
        return string.format("%.1f,%.1f", 
            component.position and component.position.x or 0, 
            component.position and component.position.y or 0)
    elseif component.class.name == "Health" then
        return tostring(component.health or 0)
    elseif component.class.name == "Resources" then
        return string.format("%d,%s", 
            component.goldAmount or 0, 
            component.state or "idle")
    elseif component.class.name == "Wallet" then
        return tostring(component.wallet or 0)
    elseif component.class.name == "Brain" then
        return string.format("%s,%s", 
            component.state or "idle",
            tostring(component.menuOpen or false))
    end
    return ""
end

-- Envoyer mise à jour seulement aux clients proches
function Entity:sendUpdateToNearbyClients()
    -- OPTIMISATION: Utiliser le gestionnaire centralisé si disponible
    if _G.EntityUpdateManager then
        _G.EntityUpdateManager:queueUpdate(self, "normal")
        return
    end
    
    -- Fallback: ancien système direct
    local position = self:getComponent("Position")
    if not position then 
        -- Si pas de position, envoyer à tous (entités globales comme UI)
        self:sendUpdate()
        return 
    end
    
    local entityPos = position.position
    if not entityPos then return end
    
    local notificationRadius = 400  -- Rayon de notification
    local clientsNotified = 0
    
    -- Créer un paquet optimisé avec seulement les données qui ont changé
    local updateData = self:createDeltaUpdate()
    
    for playerId, clientData in pairs(_G.Server.Clients or {}) do
        if clientData.udp then
            -- Vérifier la distance du joueur
            local player = _G.RealmWorld:getEntityById(playerId)
            if player then
                local playerPosition = player:getComponent("Position")
                if playerPosition and playerPosition.position then
                    local distance = math.sqrt(
                        (playerPosition.position.x - entityPos.x)^2 + 
                        (playerPosition.position.y - entityPos.y)^2
                    )
                    
                    -- Envoyer seulement aux joueurs proches
                    if distance <= notificationRadius then
                        _G.Server.Udp:send(_G.bitser.dumps({
                            id = "entity_update",
                            entityId = self.id,
                            entityData = updateData  -- Données optimisées
                        }), clientData.udp)
                        clientsNotified = clientsNotified + 1
                    end
                end
            end
        end
    end
end

-- Créer une mise à jour optimisée avec seulement les données nécessaires
function Entity:createDeltaUpdate()
    local deltaData = {
        id = self.id,
        components = {}
    }
    
    -- Inclure seulement les composants critiques qui ont changé
    for _, component in ipairs(self.components) do
        if component.class.client and self:isCriticalComponent(component.class.name) then
            if component.class.name == "Position" and component.position then
                deltaData.components.Position = {
                    position = {
                        x = math.floor(component.position.x + 0.5),  -- Arrondir pour réduire la taille
                        y = math.floor(component.position.y + 0.5)
                    }
                }
            elseif component.class.name == "Health" then
                deltaData.components.Health = {
                    health = component.health
                }
            elseif component.class.name == "Resources" then
                deltaData.components.Resources = {
                    goldAmount = component.goldAmount,
                    state = component.state,
                    maxGold = component.maxGold
                }
            elseif component.class.name == "Wallet" then
                deltaData.components.Wallet = {
                    wallet = component.wallet
                }
            elseif component.class.name == "Brain" then
                deltaData.components.Brain = {
                    state = component.state,
                    menuOpen = component.menuOpen
                }
            end
        end
    end
    
    -- Si aucun composant critique, envoyer le minimum
    if next(deltaData.components) == nil then
        deltaData = self:toNbt()  -- Fallback
    end
    
    return deltaData
end

-- Forcer une mise à jour immédiate (pour les événements importants)
function Entity:forceSyncUpdate()
    self.isDirty = true
    self.lastUpdateTime = 0  -- Forcer l'envoi immédiat
end

-- NOUVELLE MÉTHODE: Forcer l'envoi immédiat pour les entités critiques (joueurs, etc.)
function Entity:forceImmediateSync()
    print("[ENTITY-SYNC] Synchronisation forcée pour entité:", self.id)
    self.isNewEntity = true  -- Forcer le comportement de nouvelle entité
    self.isDirty = true
    self:sendUpdateToNearbyClients()
    self.isNewEntity = false
    print("[ENTITY-SYNC] Synchronisation terminée pour entité:", self.id)
end

return Entity
