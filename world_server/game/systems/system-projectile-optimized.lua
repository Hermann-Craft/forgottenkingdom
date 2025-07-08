local ProjectileSystem = require(_G.libDir .. "middleclass")("ProjectileSystem")
local Compositions = require(_G.gameDir .. "compositions")

function ProjectileSystem:initialize(world)
    self.world = world
    
    -- OPTIMISATION: Système de throttling pour réduire la fréquence des calculs de collision
    self.collisionUpdateTimer = 0
    self.collisionUpdateFrequency = 1/30 -- 30 FPS au lieu de 60 pour les collisions
    
    -- Cache pour éviter les recalculs répétitifs
    self.lastProjectilePositions = {}
    self.lastCharacterPositions = {}
    
    -- Seuil de mouvement pour déterminer si on doit recalculer les collisions
    self.movementThreshold = 3 -- pixels
    
    print("[PROJECTILE] Système optimisé initialisé - Collision: 30 FPS, Mouvement: 60 FPS")
end

-- Collision simplifiée AABB (axis-aligned bounding box) au lieu de SAT
function ProjectileSystem:simpleAABBCollision(rect1, rect2)
    return not (rect1.x > rect2.x + rect2.width or
                rect1.x + rect1.width < rect2.x or
                rect1.y > rect2.y + rect2.height or
                rect1.y + rect1.height < rect2.y)
end

-- Collision circulaire rapide pour la plupart des cas
function ProjectileSystem:circularCollision(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distanceSquared = dx * dx + dy * dy
    local radiusSum = r1 + r2
    return distanceSquared <= radiusSum * radiusSum
end

function ProjectileSystem:hasSignificantMovement(entityId, currentPos, cache)
    local lastPos = cache[entityId]
    if not lastPos then
        cache[entityId] = {x = currentPos.x, y = currentPos.y}
        return true
    end
    
    local moved = math.abs(currentPos.x - lastPos.x) > self.movementThreshold or
                  math.abs(currentPos.y - lastPos.y) > self.movementThreshold
    
    if moved then
        cache[entityId] = {x = currentPos.x, y = currentPos.y}
    end
    
    return moved
end

function ProjectileSystem:update(dt)
    local projectileEntities = self.world:getEntitiesWithStrict(Compositions.Projectile)
    local characterEntities = self.world:getEntitiesWithAtLeast(Compositions.Character)

    -- Mise à jour du mouvement des projectiles (garde 60 FPS pour la fluidité)
    self:updateProjectileMovement(projectileEntities, dt)
    
    -- OPTIMISATION: Throttling des calculs de collision
    self.collisionUpdateTimer = self.collisionUpdateTimer + dt
    if self.collisionUpdateTimer >= self.collisionUpdateFrequency then
        self.collisionUpdateTimer = 0
        self:updateCollisions(projectileEntities, characterEntities)
    end
end

function ProjectileSystem:updateProjectileMovement(projectileEntities, dt)
    for _, projectile in ipairs(projectileEntities) do
        local speed = projectile:getComponent("Speed").speed
        local position = projectile:getComponent("Position").position
        local orientation = projectile:getComponent("Orientation").orientation
        
        if speed > 0 then
            position.x = position.x + ((speed * 10) * dt) * math.cos(orientation)
            position.y = position.y + ((speed * 10) * dt) * math.sin(orientation)
        end
    end
end

function ProjectileSystem:updateCollisions(projectileEntities, characterEntities)
    -- Filtrer les entités avec mouvement significatif
    local projectilesToCheck = {}
    local charactersToCheck = {}
    
    for _, projectile in ipairs(projectileEntities) do
        local pos = projectile:getComponent("Position").position
        if self:hasSignificantMovement(projectile.id, pos, self.lastProjectilePositions) then
            table.insert(projectilesToCheck, projectile)
        end
    end
    
    for _, character in ipairs(characterEntities) do
        local pos = character:getComponent("Position").position
        if self:hasSignificantMovement(character.id, pos, self.lastCharacterPositions) then
            table.insert(charactersToCheck, character)
        end
    end
    
    -- Si aucun mouvement significatif, ne pas recalculer
    if #projectilesToCheck == 0 and #charactersToCheck == 0 then
        return
    end
    
    -- Calculs de collision optimisés
    for _, projectile in ipairs(projectileEntities) do
        local bPos = projectile:getComponent("Position").position
        local bDim = projectile:getComponent("Dimension")
        local bForce = projectile:getComponent("Force").force
        local bOwner = projectile:getComponent("Owner").ownerId
        
        for _, character in ipairs(characterEntities) do
            -- Vérification rapide de propriétaire et clan
            if bOwner == character.id then
                goto continue_character
            end
            
            local ownerEntity = self.world:getEntityById(bOwner)
            if ownerEntity then
                local ownerClan = ownerEntity:getComponent("Clan")
                local pClan = character:getComponent("Clan")
                if ownerClan and pClan and ownerClan.clanName == pClan.clanName then
                    goto continue_character
                end
            end
            
            local pPos = character:getComponent("Position").position
            local pDim = character:getComponent("Dimension")
            
            -- Collision circulaire rapide en premier
            local projectileRadius = math.max(bDim.width, bDim.height) / 2
            local characterRadius = math.max(pDim.width, pDim.height) / 2
            
            if self:circularCollision(
                bPos.x + bDim.width/2, bPos.y + bDim.height/2, projectileRadius,
                pPos.x + pDim.width/2, pPos.y + pDim.height/2, characterRadius
            ) then
                -- Collision détectée, gérer le damage
                self:handleProjectileHit(projectile, character)
            end
            
            ::continue_character::
        end
    end
end

function ProjectileSystem:handleProjectileHit(projectile, character)
    local bForce = projectile:getComponent("Force").force
    local pShield = character:getComponent("Shield")
    local pLife = character:getComponent("Life")
    
    -- Gestion du bouclier
    if pShield and pShield.activated and pShield.armor > 0 then
        pShield.armor = pShield.armor - bForce
        if pShield.armor <= 0 then
            pShield.activated = false
            print("Bouclier détruit pour", character.id)
        end
    else
        -- Damage direct à la vie
        if pLife then
            pLife.life = pLife.life - bForce
            if pLife.life <= 0 then
                print("Personnage", character.id, "éliminé")
                -- Logique de mort ici
            end
        end
    end
    
    -- Supprimer le projectile après impact
    self.world:removeEntityById(projectile.id)
end

return ProjectileSystem 
