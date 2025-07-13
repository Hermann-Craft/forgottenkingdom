local ProjectileSystem = require(_G.libDir .. "middleclass")("ProjectileSystem")
local Compositions = require(_G.gameDir .. "compositions")

local Polygon = require(_G.libDir .. "middleclass")("Polygon")
function Polygon:initialize(vertices, edges)
    self.vertex = vertices
    self.edge = edges
end

function ProjectileSystem:initialize(world)
    self.world = world
    self.debugMode = false
    
    if self.debugMode then
        print("[PROJECTILE] Système de projectiles initialisé avec debug")
    end
end

-- === ALGORITHME SAT AVANCÉ ===

function ProjectileSystem:workOutNewPoints(cx, cy, vx, vy, rotatedAngle)
    -- From a rotated object
    -- cx,cy are the centre coordinates, vx,vy is the point to be measured against the center point
    -- Convert rotated angle into radians
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

function ProjectileSystem:sat(polygonA, polygonB)
    local perpendicularLine = nil;
    local dot = 0;
    local perpendicularStack = {};
    local amin = nil;
    local amax = nil;
    local bmin = nil;
    local bmax = nil;
    
    -- Work out all perpendicular vectors on each edge for polygonA
    for i = 1, #polygonA.edge, 1 do
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
        
        -- Work out all of the dot products for all of the vertices in PolygonA against the perpendicular vector
        -- that is currently being looped through
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
        
        -- Work out all of the dot products for all of the vertices in PolygonB against the perpendicular vector
        -- that is currently being looped through
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
        
        -- If there is no gap between the dot products projection then we will continue onto evaluating the next perpendicular edge.
        if((amin < bmax and amin > bmin) or
            (bmin < amax and bmin > amin))then
            -- Continue to next perpendicular
        else
            -- Otherwise, we know that there is no collision for definite.
            return false;
        end
    end
    
    -- If we have gotten this far. Where we have looped through all of the perpendicular edges and not a single one of there projections had
    -- a gap in them. Then we know that the 2 polygons are colliding for definite then.
    return true;
end

function ProjectileSystem:getRotatedSquareCoordinates(square)
    local centerX = square.x + (square.width / 2);
    local centerY = square.y + (square.height / 2);
    
    -- Work out the new locations
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

function ProjectileSystem:detectCollision(thisRect, otherRect)
    local tRR = self:getRotatedSquareCoordinates(thisRect)
    local oRR = self:getRotatedSquareCoordinates(otherRect)
    
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
        -- Fallback to simple AABB for non-rotated objects
        if thisRect.currRotation == 0 and otherRect.currRotation == 0 then
            if not (thisRect.x > otherRect.x + otherRect.width or 
                    thisRect.x + thisRect.width < otherRect.x or 
                    thisRect.y > otherRect.y + otherRect.height or 
                    thisRect.y + thisRect.height < otherRect.y) then
                return true
            end
        end
        return false
    end
end

function ProjectileSystem:canAttack(attackerId, targetId)
    local attacker = self.world:getEntityById(attackerId)
    local target = self.world:getEntityById(targetId)
    
    if not attacker or not target then
        return false
    end
    
    -- 🔧 CORRECTION: Vérifier PvP des deux joueurs
    local attackerPlayer = attacker:getComponent("Player")
    local targetPlayer = target:getComponent("Player")
    
    if not attackerPlayer or not targetPlayer then
        return false
    end
    
    -- Les deux joueurs doivent être en mode PvP
    if not attackerPlayer.pvp or not targetPlayer.pvp then
        if self.debugMode then
            print("[PROJECTILE] Attaque bloquée - PvP désactivé (Attaquant:", attackerPlayer.pvp, "Cible:", targetPlayer.pvp, ")")
        end
        return false
    end
    
    -- 🔧 CORRECTION: Vérifier les clans - ne pas attaquer le même clan
    local attackerClan = attacker:getComponent("Clan")
    local targetClan = target:getComponent("Clan")
    
    if attackerClan and targetClan and attackerClan.clanName == targetClan.clanName then
        if self.debugMode then
            print("[PROJECTILE] Attaque bloquée - Même clan:", attackerClan.clanName)
        end
        return false
    end
    
    return true
end

function ProjectileSystem:handleProjectileHit(projectile, target)
    local bForce = projectile:getComponent("Force").force
    local pShield = target:getComponent("Shield")
    local pLife = target:getComponent("Life")
    local bOwner = projectile:getComponent("Owner").ownerId
    
    if self.debugMode then
        print("[PROJECTILE] 💥 Impact projectile:", projectile.id, "→", target.id, "Force:", bForce)
    end
    
    -- Gestion du bouclier en priorité
    if pShield and pShield.activated and pShield.armor > 0 then
        pShield.armor = pShield.armor - bForce
        if pShield.armor <= 0 then
            pShield.activated = false
            pShield.armor = 0
            if self.debugMode then
                print("[PROJECTILE] 🛡️ Bouclier détruit pour", target.id)
            end
        else
            if self.debugMode then
                print("[PROJECTILE] 🛡️ Bouclier endommagé:", pShield.armor, "restants")
            end
        end
    else
        -- Damage direct à la vie
        if pLife then
            pLife.life = pLife.life - bForce
            if self.debugMode then
                print("[PROJECTILE] ❤️ Vie réduite:", pLife.life, "restants")
            end
            
            if pLife.life <= 0 then
                pLife.life = 0
                if self.debugMode then
                    print("[PROJECTILE] ☠️ Joueur", target.id, "éliminé par", bOwner)
                end
            end
        end
    end
    
    -- Ajouter l'attaquant à la liste des attackers
    if not target.attackers then
        target.attackers = {}
    end
    
    local found = false
    for _, attacker in ipairs(target.attackers) do
        if attacker == bOwner then
            found = true
            break
        end
    end
    
    if not found then
        table.insert(target.attackers, bOwner)
    end
    
    -- Marquer le projectile pour destruction
    projectile.markDestroy = true
end

function ProjectileSystem:update(dt)
    local projectileEntities = self.world:getEntitiesWithStrict(Compositions.Projectile)
    local characterEntities = self.world:getEntitiesWithAtLeast(Compositions.Character)

    -- Move projectiles
    for _, projectile in ipairs(projectileEntities) do
        local speed = projectile:getComponent("Speed").speed
        local bPos = projectile:getComponent("Position").position
        local orientation = projectile:getComponent("Orientation").orientation
        local bDist = projectile:getComponent("Distance").distance
        
        if speed > 0 then
            bPos.x = bPos.x + ((speed * 10) * dt) * math.cos(orientation)
            bPos.y = bPos.y + ((speed * 10) * dt) * math.sin(orientation)
        end

        -- Check collisions with characters
        local bDim = projectile:getComponent("Dimension")
        local bOwner = projectile:getComponent("Owner").ownerId
        local bAngle = orientation * 180 / math.pi -- Convert to degrees for SAT
        
        for _, character in ipairs(characterEntities) do
            -- 🔧 CORRECTION: Vérifier si l'attaque est autorisée
            if not self:canAttack(bOwner, character.id) then
                goto continue_character
            end
            
            local pPos = character:getComponent("Position").position
            local pDim = character:getComponent("Dimension")
            local pRot = character:getComponent("Orientation").orientation
            local pAngle = pRot * 180 / math.pi -- Convert to degrees for SAT
            
            -- 🔧 CORRECTION: Utiliser SAT pour collision projectile-joueur
            local projectileRect = {
                x = bPos.x, 
                y = bPos.y, 
                width = bDim.width, 
                height = bDim.height, 
                currRotation = bAngle
            }
            
            local characterRect = {
                x = pPos.x, 
                y = pPos.y, 
                width = pDim.width, 
                height = pDim.height, 
                currRotation = pAngle
            }
            
            if self:detectCollision(projectileRect, characterRect) then
                self:handleProjectileHit(projectile, character)
                goto continue_character -- Projectile déjà marqué pour destruction
            end
            
            ::continue_character::
        end

        -- Destroy projectile after maximum distance
        if projectile.origin then
            local longAB = function(field) 
                return (bPos[field] - projectile.origin[field]) * (bPos[field] - projectile.origin[field]) 
            end
            local distance = math.sqrt(longAB("x") + longAB("y"))
            
            if distance > bDist then
                self.world:removeEntityById(projectile.id)
            end
        end
    end
end

function ProjectileSystem:setDebugMode(enabled)
    self.debugMode = enabled
    if enabled then
        print("[PROJECTILE] 🔧 Mode debug ACTIVÉ")
    else
        print("[PROJECTILE] 🔧 Mode debug DÉSACTIVÉ")
    end
end

return ProjectileSystem
