-- Système de collision dédié avec algorithme SAT avancé du system-projectile
-- Réutilise l'algorithme de collision complexe avec rotation prise en compte
local CollisionSystem = require(_G.libDir .. "middleclass")("CollisionSystem")
local System = require(_G.engineDir .. "system")
CollisionSystem.static.super = System

local Polygon = require(_G.libDir .. "middleclass")("Polygon")
function Polygon:initialize(vertices, edges)
    self.vertex = vertices
    self.edge = edges
end

function CollisionSystem:initialize(world, debugMode)
    System.initialize(self, world)
    self.debugMode = debugMode or false
    
    -- 🔧 HYSTÉRÉSIS: Zones étendues pour éviter le spam START/END
    self.villagerInteractionRadius = 30     -- Zone de base pour villageois  
    self.villagerHysteresisRadius = 50      -- Zone étendue pour hystérésis (END plus tard)
    self.mineInteractionRadius = 60         -- Zone de base pour mines
    self.mineHysteresisRadius = 80          -- Zone étendue pour hystérésis (END plus tard)
    
    -- Tracking des collisions actuelles
    self.currentCollisions = {
        villagers = {},  -- {playerId = {villagerId = {type = "hireable|worker", timestamp = time, inHysteresis = bool}}}
        mines = {}       -- {playerId = {mineId = {timestamp = time, inHysteresis = bool}}}
    }
    
    -- Callbacks pour les événements de collision
    self.onCollisionStart = {}  -- {villager = func, mine = func}
    self.onCollisionEnd = {}    -- {villager = func, mine = func}
    
    if self.debugMode then
        print("[COLLISION] Système de collision SAT pur initialisé")
        print("[COLLISION] ✅ AUCUN pré-filtrage par distance - SAT/AABB uniquement")
        print("[COLLISION] 🔄 Hystérésis - Villageois:", self.villagerInteractionRadius, "→", self.villagerHysteresisRadius, "px")
        print("[COLLISION] 🔄 Hystérésis - Mines:", self.mineInteractionRadius, "→", self.mineHysteresisRadius, "px")
    end
end

-- === ALGORITHME SAT AVANCÉ (du system-projectile) ===

function CollisionSystem:workOutNewPoints(cx, cy, vx, vy, rotatedAngle)
    --From a rotated object
    --cx,cy are the centre coordinates, vx,vy is the point to be measured against the center point
        --Convert rotated angle into radians
        rotatedAngle = rotatedAngle * math.pi / 180;
        local dx = vx - cx;
        local dy = vy - cy;
        local distance = math.sqrt(dx * dx + dy * dy);
        local originalAngle = math.atan2(dy,dx);
        local rotatedX = cx + distance * math.cos(originalAngle + rotatedAngle);
        local rotatedY = cy + distance * math.sin(originalAngle + rotatedAngle);
    
        return {
            x = rotatedX,
            y = rotatedY
        }
end

function CollisionSystem:sat(polygonA, polygonB)
    local perpendicularLine = nil;
    local dot = 0;
    local perpendicularStack = {};
    local amin = nil;
    local amax = nil;
    local bmin = nil;
    local bmax = nil;
    --Work out all perpendicular vectors on each edge for polygonA
    for  i = 1, #polygonA.edge, 1 do
        perpendicularLine = { x = -polygonA.edge[i].y, y = polygonA.edge[i].x };
        table.insert(perpendicularStack, #perpendicularStack + 1, perpendicularLine)
    end
    -- Work out all perpendicular vectors on each edge for polygonB
    for i = 1, #polygonB.edge, 1 do
        perpendicularLine = { x = -polygonB.edge[i].y, y = polygonB.edge[i].x };
        table.insert(perpendicularStack, #perpendicularStack + 1, perpendicularLine)
    end
    -- Loop through each perpendicular vector for both polygons
    for i = 1, #perpendicularStack, 1 do
        -- These dot products will return different values each time
         amin = nil;
         amax = nil;
         bmin = nil;
         bmax = nil;
         --Work out all of the dot products for all of the vertices in PolygonA against the perpendicular vector
         -- that is currently being looped through*/
         for j = 1, #polygonA.vertex, 1 do
              dot = polygonA.vertex[j].x *
                    perpendicularStack[i].x +
                    polygonA.vertex[j].y *
                    perpendicularStack[i].y;
            -- Then find the dot products with the highest and lowest values from polygonA.
              if(amax == nil or dot > amax) then
                   amax = dot
              end
              if(amin == nil or dot < amin) then
                   amin = dot;
              end
        end
         --Work out all of the dot products for all of the vertices in PolygonB against the perpendicular vector
         -- that is currently being looped through*/
         for j = 1, #polygonB.vertex, 1 do
              dot = polygonB.vertex[j].x *
                    perpendicularStack[i].x +
                    polygonB.vertex[j].y *
                    perpendicularStack[i].y;
            -- Then find the dot products with the highest and lowest values from polygonB.
              if(bmax == nil or dot > bmax) then
                   bmax = dot;
              end
              if(bmin == nil or dot < bmin) then
                   bmin = dot;
              end
        end
        --If there is no gap between the dot products projection then we will continue onto evaluating the next perpendicular edge.
        if((amin < bmax and amin > bmin) or
            (bmin < amax and bmin > amin))then
            
         --Otherwise, we know that there is no collision for definite.
         else
              return false;
         end
    end
    -- If we have gotten this far. Where we have looped through all of the perpendicular edges and not a single one of there projections had
    -- a gap in them. Then we know that the 2 polygons are colliding for definite then.*/
    return true;
end

function CollisionSystem:getRotatedSquareCoodinates(square)
    local centerX = square.x + (square.width / 2);
    local centerY = square.y + (square.height / 2);
    --Work out the new locations
    local topLeft = self:workOutNewPoints(centerX, centerY, square.x, square.y, square.currRotation);
    local topRight = self:workOutNewPoints(centerX, centerY, square.x + square.width, square.y, square.currRotation);
    local bottomLeft = self:workOutNewPoints(centerX, centerY, square.x, square.y + square.height, square.currRotation);
    local bottomRight = self:workOutNewPoints(centerX, centerY, square.x + square.width, square.y + square.height, square.currRotation);
    return{
        tl = topLeft,
        tr = topRight,
        bl = bottomLeft,
        br = bottomRight
    }
end

function CollisionSystem:detectCollision(thisRect, otherRect)
    local tRR = self:getRotatedSquareCoodinates(thisRect)
    local oRR = self:getRotatedSquareCoodinates(otherRect)
    local thisTankVertices = {
        { x = tRR.tr.x, y = tRR.tr.y },
        { x = tRR.br.x, y = tRR.br.y },
        { x = tRR.bl.x, y = tRR.bl.y },
        { x = tRR.tl.x, y = tRR.tl.y },
    }
    local thisTankEdges = {
        { x = tRR.br.x - tRR.tr.x, y = tRR.br.y - tRR.tr.y},
        { x = tRR.bl.x - tRR.br.x, y = tRR.bl.y - tRR.br.y},
        { x = tRR.tl.x - tRR.bl.x, y = tRR.tl.y - tRR.bl.y},
        { x = tRR.tr.x - tRR.tl.x, y = tRR.tr.y - tRR.tl.y},
    }
    local otherTankVertices = {
        { x = oRR.tr.x, y = oRR.tr.y },
        { x = oRR.br.x, y = oRR.br.y },
        { x = oRR.bl.x, y = oRR.bl.y },
        { x = oRR.tl.x, y = oRR.tl.y },
    }
    local otherTankEdges = {
        { x = oRR.br.x - oRR.tr.x, y = oRR.br.y - oRR.tr.y},
        { x = oRR.bl.x - oRR.br.x, y = oRR.bl.y - oRR.br.y},
        { x = oRR.tl.x - oRR.bl.x, y = oRR.tl.y - oRR.bl.y},
        { x = oRR.tr.x - oRR.tl.x, y = oRR.tr.y - oRR.tl.y},
    }
    local thisRectPolygon = Polygon:new(thisTankVertices, thisTankEdges)
    local otherRectPolygon = Polygon:new(otherTankVertices, otherTankEdges)
    if self:sat(thisRectPolygon, otherRectPolygon) then
        return true
    else
        if thisRect.currRotation == 0 and otherRect.currRotation == 0 then
            if not (thisRect.x>otherRect.x+otherRect.width or thisRect.x+thisRect.width < otherRect.x or thisRect.y > otherRect.y + otherRect.height or thisRect.y+thisRect.height < otherRect.y) then
                return true
            end
        else
            return false
        end
    end
end

-- === MÉTHODES DE COLLISION POUR ENTITÉS ===

function CollisionSystem:createEntityRect(entity)
    local pos = entity:getComponent("Position")
    local dim = entity:getComponent("Dimension")
    local orientation = entity:getComponent("Orientation")
    
    if not pos or not dim then
        return nil
    end
    
    local angle = 0
    if orientation then
        angle = orientation.orientation * 180 / math.pi  -- Convertir en degrés
    end
    
    return {
        x = pos.position.x,
        y = pos.position.y,
        width = dim.width,
        height = dim.height,
        currRotation = angle
    }
end

function CollisionSystem:calculateDistance(entity1, entity2)
    local pos1 = entity1:getComponent("Position")
    local pos2 = entity2:getComponent("Position")
    local dim1 = entity1:getComponent("Dimension")
    local dim2 = entity2:getComponent("Dimension")
    
    if not pos1 or not pos2 or not dim1 or not dim2 then
        return math.huge
    end
    
    -- Distance entre centres
    local centerX1 = pos1.position.x + dim1.width / 2
    local centerY1 = pos1.position.y + dim1.height / 2
    local centerX2 = pos2.position.x + dim2.width / 2
    local centerY2 = pos2.position.y + dim2.height / 2
    
    local dx = centerX1 - centerX2
    local dy = centerY1 - centerY2
    
    return math.sqrt(dx * dx + dy * dy)
end

function CollisionSystem:update(dt)
    -- Obtenir toutes les entités
    local players = self.world:getEntitiesWithAtLeast({"Player"})
    local hireableVillagers = self.world:getEntitiesWithAtLeast({"Villager", "Hireable"})
    local workerVillagers = self.world:getEntitiesWithAtLeast({"Villager", "Worker"})
    local mines = self.world:getEntitiesWithAtLeast({"Resources"})  -- Mines d'or
    
    -- Vérifier toutes les collisions avec l'algorithme SAT
    self:checkPlayerVillagerCollisions(players, hireableVillagers, "hireable")
    self:checkPlayerVillagerCollisions(players, workerVillagers, "worker")
    self:checkPlayerMineCollisions(players, mines)
end

function CollisionSystem:checkPlayerVillagerCollisions(players, villagers, villagerType)
    local currentFrame = {}
    
    for _, player in ipairs(players) do
        local playerId = player.id
        local playerRect = self:createEntityRect(player)
        if not playerRect then goto continue_player end
        
        currentFrame[playerId] = {}
        
        for _, villager in ipairs(villagers) do
            local villagerId = villager.id
            local villagerRect = self:createEntityRect(villager)
            if not villagerRect then goto continue_villager end
            
            -- 🔧 COLLISION SAT/AABB PURE - Pas de pré-filtrage par distance
            local isColliding = self:detectCollision(playerRect, villagerRect)
            
            if isColliding then
                -- Collision détectée avec algorithme SAT/AABB
                local distance = self:calculateDistance(player, villager)
                currentFrame[playerId][villagerId] = {
                    type = villagerType,
                    distance = distance,
                    timestamp = love.timer.getTime(),
                    inHysteresis = false  -- Dans la zone de base
                }
                
                -- Vérifier si c'est une nouvelle collision
                if not (self.currentCollisions.villagers[playerId] and 
                        self.currentCollisions.villagers[playerId][villagerId]) then
                    self:onVillagerCollisionStart(playerId, villagerId, villager, villagerType, distance)
                end
            else
                -- Pas de collision directe, vérifier l'hystérésis pour les collisions existantes
                local existingCollision = self.currentCollisions.villagers[playerId] and 
                                         self.currentCollisions.villagers[playerId][villagerId]
                
                if existingCollision and existingCollision.type == villagerType then
                    -- 🔄 HYSTÉRÉSIS: Créer zone étendue pour éviter spam END
                    local hysteresisRect = {
                        x = villagerRect.x - self.villagerHysteresisRadius,
                        y = villagerRect.y - self.villagerHysteresisRadius, 
                        width = villagerRect.width + (self.villagerHysteresisRadius * 2),
                        height = villagerRect.height + (self.villagerHysteresisRadius * 2),
                        currRotation = 0  -- Zone rectangulaire simple pour hystérésis
                    }
                    
                    if self:detectCollision(playerRect, hysteresisRect) then
                        -- Toujours dans la zone d'hystérésis - maintenir la collision
                        local distance = self:calculateDistance(player, villager)
                        currentFrame[playerId][villagerId] = {
                            type = villagerType,
                            distance = distance,
                            timestamp = love.timer.getTime(),
                            inHysteresis = true  -- Dans la zone étendue
                        }
                    end
                    -- Sinon, la collision va se terminer (sortie de zone d'hystérésis)
                end
            end
            
            ::continue_villager::
        end
        
        ::continue_player::
    end
    
    -- Détecter les collisions qui se terminent ET les nettoyer
    if self.currentCollisions.villagers then
        for playerId, villagers in pairs(self.currentCollisions.villagers) do
            for villagerId, collisionData in pairs(villagers) do
                if collisionData.type == villagerType then
                    if not (currentFrame[playerId] and currentFrame[playerId][villagerId]) then
                        -- Collision terminée - déclencher callback et nettoyer
                        self:onVillagerCollisionEnd(playerId, villagerId, villagerType)
                        
                        -- 🔧 CORRECTION: Nettoyer immédiatement l'entrée
                        self.currentCollisions.villagers[playerId][villagerId] = nil
                        
                        -- Nettoyer la table du joueur si vide
                        if next(self.currentCollisions.villagers[playerId]) == nil then
                            self.currentCollisions.villagers[playerId] = nil
                        end
                    end
                end
            end
        end
    end
    
    -- 🔧 CORRECTION: Remplacer complètement les données au lieu d'ajouter
    for playerId, villagers in pairs(currentFrame) do
        if not self.currentCollisions.villagers[playerId] then
            self.currentCollisions.villagers[playerId] = {}
        end
        
        -- Remplacer seulement les villageois du type actuel
        for villagerId, collisionData in pairs(villagers) do
            self.currentCollisions.villagers[playerId][villagerId] = collisionData
        end
    end
    
    -- 🔧 CORRECTION: Nettoyer les joueurs sans collisions de ce type
    if self.currentCollisions.villagers then
        for playerId, villagers in pairs(self.currentCollisions.villagers) do
            if not currentFrame[playerId] then
                -- Aucune collision pour ce joueur dans cette frame
                -- Supprimer toutes les collisions du type actuel
                for villagerId, collisionData in pairs(villagers) do
                    if collisionData.type == villagerType then
                        self.currentCollisions.villagers[playerId][villagerId] = nil
                    end
                end
                
                -- Nettoyer la table du joueur si vide
                if next(self.currentCollisions.villagers[playerId]) == nil then
                    self.currentCollisions.villagers[playerId] = nil
                end
            end
        end
    end
end

function CollisionSystem:checkPlayerMineCollisions(players, mines)
    local currentFrame = {}
    
    for _, player in ipairs(players) do
        local playerId = player.id
        local playerRect = self:createEntityRect(player)
        if not playerRect then goto continue_player end
        
        currentFrame[playerId] = {}
        
        for _, mine in ipairs(mines) do
            local mineId = mine.id
            local mineRect = self:createEntityRect(mine)
            if not mineRect then goto continue_mine end
            
            -- 🔧 COLLISION SAT/AABB PURE - Pas de pré-filtrage par distance
            local isColliding = self:detectCollision(playerRect, mineRect)
            
            if isColliding then
                -- Collision détectée avec algorithme SAT/AABB
                local distance = self:calculateDistance(player, mine)
                currentFrame[playerId][mineId] = {
                    distance = distance,
                    timestamp = love.timer.getTime(),
                    inHysteresis = false  -- Dans la zone de base
                }
                
                -- Vérifier si c'est une nouvelle collision
                if not (self.currentCollisions.mines[playerId] and 
                        self.currentCollisions.mines[playerId][mineId]) then
                    self:onMineCollisionStart(playerId, mineId, mine, distance)
                end
            else
                -- Pas de collision directe, vérifier l'hystérésis pour les collisions existantes
                local existingCollision = self.currentCollisions.mines[playerId] and 
                                         self.currentCollisions.mines[playerId][mineId]
                
                if existingCollision then
                    -- 🔄 HYSTÉRÉSIS: Créer zone étendue pour éviter spam END
                    local hysteresisRect = {
                        x = mineRect.x - self.mineHysteresisRadius,
                        y = mineRect.y - self.mineHysteresisRadius, 
                        width = mineRect.width + (self.mineHysteresisRadius * 2),
                        height = mineRect.height + (self.mineHysteresisRadius * 2),
                        currRotation = 0  -- Zone rectangulaire simple pour hystérésis
                    }
                    
                    if self:detectCollision(playerRect, hysteresisRect) then
                        -- Toujours dans la zone d'hystérésis - maintenir la collision
                        local distance = self:calculateDistance(player, mine)
                        currentFrame[playerId][mineId] = {
                            distance = distance,
                            timestamp = love.timer.getTime(),
                            inHysteresis = true  -- Dans la zone étendue
                        }
                    end
                    -- Sinon, la collision va se terminer (sortie de zone d'hystérésis)
                end
            end
            
            ::continue_mine::
        end
        
        ::continue_player::
    end
    
    -- Détecter les collisions qui se terminent ET les nettoyer
    if self.currentCollisions.mines then
        for playerId, mines in pairs(self.currentCollisions.mines) do
            for mineId, collisionData in pairs(mines) do
                if not (currentFrame[playerId] and currentFrame[playerId][mineId]) then
                    -- Collision terminée - déclencher callback et nettoyer
                    self:onMineCollisionEnd(playerId, mineId)
                    
                    -- 🔧 CORRECTION: Nettoyer immédiatement l'entrée
                    self.currentCollisions.mines[playerId][mineId] = nil
                    
                    -- Nettoyer la table du joueur si vide
                    if next(self.currentCollisions.mines[playerId]) == nil then
                        self.currentCollisions.mines[playerId] = nil
                    end
                end
            end
        end
    end
    
    -- 🔧 CORRECTION: Remplacer complètement les données au lieu d'ajouter
    for playerId, mines in pairs(currentFrame) do
        if not self.currentCollisions.mines[playerId] then
            self.currentCollisions.mines[playerId] = {}
        end
        
        -- Remplacer les données de mines pour ce joueur
        for mineId, collisionData in pairs(mines) do
            self.currentCollisions.mines[playerId][mineId] = collisionData
        end
    end
    
    -- 🔧 CORRECTION: Nettoyer les joueurs sans collisions
    if self.currentCollisions.mines then
        for playerId, mines in pairs(self.currentCollisions.mines) do
            if not currentFrame[playerId] then
                -- Aucune collision pour ce joueur dans cette frame - nettoyer
                self.currentCollisions.mines[playerId] = nil
            end
        end
    end
end

-- === CALLBACKS ET ÉVÉNEMENTS ===

function CollisionSystem:setVillagerCallbacks(onStart, onEnd)
    self.onCollisionStart.villager = onStart
    self.onCollisionEnd.villager = onEnd
end

function CollisionSystem:setMineCallbacks(onStart, onEnd)
    self.onCollisionStart.mine = onStart
    self.onCollisionEnd.mine = onEnd
end

function CollisionSystem:onVillagerCollisionStart(playerId, villagerId, villager, villagerType, distance)
    if self.debugMode then
        print("[COLLISION] ✅ Collision START: " .. playerId .. " → " .. villagerId .. " (" .. villagerType .. ", " .. math.floor(distance) .. "px)")
    end
    
    if self.onCollisionStart.villager then
        self.onCollisionStart.villager(playerId, villagerId, villager, villagerType, distance)
    end
end

function CollisionSystem:onVillagerCollisionEnd(playerId, villagerId, villagerType)
    if self.debugMode then
        print("[COLLISION] ❌ Collision END: " .. playerId .. " ← " .. villagerId .. " (" .. villagerType .. ")")
    end
    
    if self.onCollisionEnd.villager then
        self.onCollisionEnd.villager(playerId, villagerId, villagerType)
    end
end

function CollisionSystem:onMineCollisionStart(playerId, mineId, mine, distance)
    if self.debugMode then
        print("[COLLISION] ⛏️ Mine collision START: " .. playerId .. " → " .. mineId .. " (" .. math.floor(distance) .. "px)")
    end
    
    if self.onCollisionStart.mine then
        self.onCollisionStart.mine(playerId, mineId, mine, distance)
    end
end

function CollisionSystem:onMineCollisionEnd(playerId, mineId)
    if self.debugMode then
        print("[COLLISION] ⛏️ Mine collision END: " .. playerId .. " ← " .. mineId)
    end
    
    if self.onCollisionEnd.mine then
        self.onCollisionEnd.mine(playerId, mineId)
    end
end

-- === MÉTHODES UTILITAIRES ===

function CollisionSystem:isPlayerNearVillager(playerId, villagerId)
    return self.currentCollisions.villagers[playerId] and 
           self.currentCollisions.villagers[playerId][villagerId] ~= nil
end

function CollisionSystem:isPlayerNearMine(playerId, mineId)
    return self.currentCollisions.mines[playerId] and 
           self.currentCollisions.mines[playerId][mineId] ~= nil
end

function CollisionSystem:setDebugMode(enabled)
    self.debugMode = enabled
    if enabled then
        print("[COLLISION] 🔧 Mode debug ACTIVÉ - Algorithme SAT avancé")
    else
        print("[COLLISION] 🔧 Mode debug DÉSACTIVÉ")
    end
end

return CollisionSystem 
