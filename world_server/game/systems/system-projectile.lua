local ProjectileSystem = require(_G.libDir .. "middleclass")("ProjectileSystem")
local Polygon = require(_G.libDir .. "middleclass")("Polygon")
function Polygon:initialize(vertices, edges)
    self.vertex = vertices
    self.edge = edges
end
local Compositions = require(_G.gameDir .. "compositions")

function ProjectileSystem:initialize( world )
    self.world = world
end

function workOutNewPoints(cx, cy, vx, vy, rotatedAngle)
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

function sat(polygonA, polygonB)

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

function getRotatedSquareCoodinates(square)
    local centerX = square.x + (square.width / 2);
    local centerY = square.y + (square.height / 2);
    --Work out the new locations
    local topLeft = workOutNewPoints(centerX, centerY, square.x, square.y, square.currRotation);
    local topRight = workOutNewPoints(centerX, centerY, square.x + square.width, square.y, square.currRotation);
    local bottomLeft = workOutNewPoints(centerX, centerY, square.x, square.y + square.height, square.currRotation);
    local bottomRight = workOutNewPoints(centerX, centerY, square.x + square.width, square.y + square.height, square.currRotation);
    return{
        tl = topLeft,
        tr = topRight,
        bl = bottomLeft,
        br = bottomRight
    }
end

function detectCollision(thisRect, otherRect)
    local tRR = getRotatedSquareCoodinates(thisRect)
    local oRR = getRotatedSquareCoodinates(otherRect)
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
    if sat(thisRectPolygon, otherRectPolygon) then
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

function ProjectileSystem:update(dt)
    local projectileEntities = self.world:getEntitiesWithStrict(Compositions.Projectile)
    local characterEntities = self.world:getEntitiesWithAtLeast(Compositions.Character)

    -- Move projectile
    for _, v in ipairs(projectileEntities) do
        local speed = v:getComponent("Speed").speed
        local bPos = v:getComponent("Position").position
        local bDim = v:getComponent("Dimension")
        local bForce = v:getComponent("Force").force
        local orientation = v:getComponent("Orientation").orientation
        local bOwner = v:getComponent("Owner").ownerId
        local bDist = v:getComponent("Distance").distance
        local bAngle = orientation * 180 / math.pi
        if speed > 0 then
            bPos.x = bPos.x + ((speed * 10) * dt) * math.cos(orientation)
            bPos.y = bPos.y + ((speed * 10) * dt) * math.sin(orientation)
        end

        -- Collision
        for _, char in ipairs(characterEntities) do
            local pShield = char:getComponent("Shield")
            local pPos = char:getComponent("Position").position
            local pDim = char:getComponent("Dimension")
            local pRot = char:getComponent("Orientation").orientation
            local pLife = char:getComponent("Life")
            local pClan = char:getComponent("Clan")
            local pAngle = pRot * 180 / math.pi
            
            local ownerEntity = self.world:getEntityById(bOwner);
            local ownerClan = ownerEntity:getComponent("Clan")
            if bOwner ~= char.id or ownerClan.clanName ~= pClan.clanName then -- check if he is same clan of owner
                if pShield then
                    if pShield.activated and pShield.armor > 0 then
                        local sPos =  { x = pPos.x + 16 + 32 * math.cos(pRot), y = pPos.y + 16 + 32 * math.sin(pRot) }
                        if detectCollision(
                            { x = bPos.x, y = bPos.y, width = bDim.width, height = bDim.height, currRotation = bAngle },
                            { x = pPos.x + 48 * math.cos(pRot), y = pPos.y + 48 * math.sin(pRot), width = 8, height = 48, currRotation = pAngle }
                        ) then
                            pShield.armor = pShield.armor - bForce

                            local found = nil
                            for i, attacker in ipairs(char.attackers) do
                                if attacker == bOwner then found = v end
                            end
                            if found == nil then
                                table.insert(char.attackers, #char.attackers + 1, bOwner)
                            end
                            v.markDestroy = true
                        end
                    end
                else
                    if detectCollision(
                        { x = bPos.x, y = bPos.y, width = bDim.width, height = bDim.height, currRotation = orientation},
                        { x = pPos.x, y = pPos.y, width = pDim.width, height = pDim.height, currRotation = pRot}
                    ) then
                        print("dzadaz")
                        pLife.life = pLife.life - bForce

                        local found = nil
                        for i, attacker in ipairs(char.attackers) do
                            if attacker == bOwner then found = v end
                        end
                        if found == nil then
                            table.insert(char.attackers, #char.attackers + 1, bOwner)
                        end

                        v.markDestroy = true
                    end
                end
                if detectCollision(
                    { x = bPos.x, y = bPos.y, width = bDim.width, height = bDim.height, currRotation = orientation},
                    { x = pPos.x, y = pPos.y, width = pDim.width, height = pDim.height, currRotation = pRot}
                ) then
                    print("dzadaz")
                    pLife.life = pLife.life - bForce

                    local found = nil
                    for i, attacker in ipairs(char.attackers) do
                        if attacker == bOwner then found = v end
                    end
                    if found == nil then
                        table.insert(char.attackers, #char.attackers + 1, bOwner)
                    end

                    v.markDestroy = true
                end
            end
        end

        -- destroy after distance
        local longAB = function ( field ) return (bPos[field] - v.origin[field]) * (bPos[field] - v.origin[field]) end
        local longueur = math.sqrt(longAB("x") + longAB("y"))
        if longueur > bDist then -- distance
            self.world:removeEntityById(v.id)
        end
    end
end

return ProjectileSystem
