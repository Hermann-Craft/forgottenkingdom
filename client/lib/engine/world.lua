local World = require(_G.libDir .. "middleclass")("World")

function World:initialize(width, height, entities)
    self.width = width or 100
    self.height = height or 100
    self.entities = entities or {}
    self.camera = require(_G.libDir .. "camera")()
    
    -- Gestionnaire de textures
    self.textureManager = require(_G.engineDir .. "texture_manager"):new()
    self.textureManager:preloadTextures()
    
    -- Indicateurs visuels
    self.nearbyMineIndicators = {} -- Indicateurs pour les mines proches
    
    self.tools = {
        gridSize = {
            width = 16,
            height = 16
        }
    }

    self.debugActivated = false
end

function World:getEntityById( entityId )
    local entity = nil
    for i, e in ipairs(self.entities) do
        if e.id == entityId then
            entity = e
        end
    end
    return entity
end

function World:addEntity(entityData)
    table.insert(self.entities, #self.entities + 1, entityData)
end

function World:updateEntity(entityId, entityData)
    for i, v in ipairs(self.entities) do
        if v.id == entityId then
            v.components = entityData.components
        end
    end
end
 
function World:removeEntity(entityId, entityData)
    for i, v in ipairs(self.entities) do
        if v.id == entityId then
            table.remove(self.entities, i)
        end
    end
end

function World:update()
    for i, entity in ipairs(self.entities) do
        if entity.id == _G.user.email then
            if entity.components["Position"] then
                local ePos = entity.components["Position"].position
                self.camera:lookAt(ePos.x, ePos.y)
            end
        end
    end
end

function World:draw()
    self.camera:attach()
        local selfEntity = self:getEntityById(_G.user.email)
        love.graphics.rectangle("line", 0, 0, self.width, self.height)
        for i, entity in ipairs(self.entities) do
            local ePos = entity.components["Position"]
            local eDim = entity.components["Dimension"]
            local eOri = entity.components["Orientation"]
            local eShield = entity.components["Shield"]
            local eLife = entity.components["Life"]
            local eClan = entity.components["Clan"]
            local eName = entity.components["Name"]
            local eTexture = entity.components["Texture"]
            local eResources = entity.components["Resources"]
            
            if ePos and eDim and eOri then
                -- Dessiner l'entité avec texture si disponible
                if eTexture then
                    self:drawEntityWithTexture(entity, ePos, eDim, eOri, eTexture, eResources)
                else
                    -- Fallback: rectangle simple
                    love.graphics.push()
                    love.graphics.translate(ePos.position.x + eDim.width / 2, ePos.position.y + eDim.height / 2)
                    love.graphics.rotate(eOri.orientation)
                    love.graphics.rectangle("fill", -(eDim.width/2), -(eDim.height/2), eDim.width , eDim.height)
                    love.graphics.pop()
                end
            end
            if ePos and eDim and eOri and eLife then
                love.graphics.setColor(1,0,0,1)
                love.graphics.rectangle("fill", ePos.position.x, ePos.position.y - eDim.width / 2, 32 * (eLife.life / eLife.maxLife ), 8 )
                love.graphics.setColor(1,1,1,1)
                love.graphics.rectangle("line", ePos.position.x, ePos.position.y - eDim.width / 2, 32, 8 )
                love.graphics.push()
                love.graphics.translate(ePos.position.x + eDim.width / 2, ePos.position.y + eDim.height / 2)
                love.graphics.rotate(eOri.orientation)
                love.graphics.rectangle("fill", -(eDim.width/2), -(eDim.height/2), eDim.width , eDim.height)
                love.graphics.pop()
            end
            if ePos and eDim and eOri and eShield and eLife and eClan then
                if entity.id ~= _G.user.selectedCharacter then
                    if selfEntity then
                        if eClan.clanName ~= selfEntity.components["Clan"].clanName then
                            love.graphics.setColor(1, 0, 0, 1)
                        else
                            love.graphics.setColor(0, 1, 0, 1)
                        end
                    end
                    love.graphics.print(eClan.clanName, ePos.position.x, ePos.position.y - 32)
                    love.graphics.push()
                    love.graphics.translate(ePos.position.x + eDim.width / 2, ePos.position.y + eDim.height / 2)
                    love.graphics.rotate(eOri.orientation)
                    love.graphics.rectangle("line", -(eDim.width/2), -(eDim.height/2), eDim.width , eDim.height)
                    love.graphics.pop()
                    love.graphics.setColor(1,1,1,1)
                end
                love.graphics.push()
                love.graphics.translate(ePos.position.x + eDim.width / 2, ePos.position.y + eDim.height / 2)
                love.graphics.rotate(eOri.orientation)
                love.graphics.rectangle("fill", -(eDim.width/2), -(eDim.height/2), eDim.width , eDim.height)
                love.graphics.pop()
                -- life
                love.graphics.setColor(1,0,0,1)
                love.graphics.rectangle("fill", ePos.position.x, ePos.position.y - eDim.width / 2, 32 * (eLife.life / eLife.maxLife ), 8 )
                love.graphics.setColor(1,1,1,1)
                love.graphics.rectangle("line", ePos.position.x, ePos.position.y - eDim.width / 2, 32, 8 )
                if eShield.activated then
                    love.graphics.setColor(0,0,1, eShield.armor / 100)
                    love.graphics.push()
                    love.graphics.translate(ePos.position.x + 4 + (48 * math.cos(eOri.orientation)), ePos.position.y + 24 + (48 * math.sin(eOri.orientation)))
                    love.graphics.rotate(eOri.orientation)
                    love.graphics.rectangle("fill", -4, -24, 8, 48)
                    love.graphics.pop()
                    love.graphics.setColor(1,1,1,1)
                end
            end
        end
        -- Dessiner les indicateurs de proximité des mines
        self:drawMineProximityIndicators()
        
        if self.debugActivated then
            self:drawDebug()
        end
    self.camera:detach()
end

function World:drawDebug()
    love.graphics.rectangle("line", 0, 0, self.width, self.height)
    -- draw grid
    mx, my = self.camera:mousePosition()
    for x=0, self.width / self.tools.gridSize.width do
        for y=0, self.height / self.tools.gridSize.height do
            love.graphics.rectangle("line", x * self.tools.gridSize.width, y * self.tools.gridSize.height, self.tools.gridSize.width, self.tools.gridSize.height )
            if mx > x * self.tools.gridSize.width and mx < (x * self.tools.gridSize.width) + self.tools.gridSize.width and my > y * self.tools.gridSize.height and my < (y * self.tools.gridSize.height) + self.tools.gridSize.height then
                love.graphics.rectangle("fill", x * self.tools.gridSize.width, y * self.tools.gridSize.height, self.tools.gridSize.width, self.tools.gridSize.height )
            end
        end
    end 
end

function World:keyreleased(key)
    if key == m then
        self.debugActivated = not self.debugActivated
    end
end

function World:mousereleased()
    mx, my = self.camera:mousePosition()
    for x=0, self.width / self.tools.gridSize.width do
        for y=0, self.height / self.tools.gridSize.height do
            if mx > x * self.tools.gridSize.width and mx < (x * self.tools.gridSize.width) + self.tools.gridSize.width and my > y * self.tools.gridSize.height and my < (y * self.tools.gridSize.height) + self.tools.gridSize.height then
                self:addEntity({
                    id = "test",
                    components = {
                        Position = {
                            position = {
                                x = x * self.tools.gridSize.width,
                                y = y * self.tools.gridSize.height
                            }
                        },
                        Dimension= {
                            width = 16,
                            height = 16
                        },
                        Orientation = {
                            orientation = 0
                        }
                    }
                })
            end
        end
    end
end

function World:drawEntityWithTexture(entity, ePos, eDim, eOri, eTexture, eResources)
    -- Obtenir la texture appropriée
    local texture = self.textureManager:getTextureByComponent(eTexture)
    
    if not texture then
        -- Fallback si pas de texture
        love.graphics.push()
        love.graphics.translate(ePos.position.x + eDim.width / 2, ePos.position.y + eDim.height / 2)
        love.graphics.rotate(eOri.orientation)
        love.graphics.rectangle("fill", -(eDim.width/2), -(eDim.height/2), eDim.width , eDim.height)
        love.graphics.pop()
        return
    end
    
    -- Appliquer la couleur selon l'état (pour les mines d'or)
    local colorR, colorG, colorB, colorA = 1, 1, 1, 1
    
    if eResources and eTexture.name == "goldmine" then
        -- Colorer les mines selon leur état
        if eResources.state == "full" then
            colorR, colorG, colorB = 1, 0.84, 0 -- Doré
        elseif eResources.state == "partial" then
            colorR, colorG, colorB = 1, 0.9, 0.3 -- Doré pâle
        elseif eResources.state == "low" then
            colorR, colorG, colorB = 0.9, 0.8, 0.4 -- Jaunâtre
        elseif eResources.state == "respawning" then
            colorR, colorG, colorB = 0.6, 0.6, 0.6 -- Gris
            colorA = 0.7 -- Semi-transparent
        end
    end
    
    love.graphics.setColor(colorR, colorG, colorB, colorA)
    
    -- Dessiner la texture
    love.graphics.push()
    love.graphics.translate(ePos.position.x + eDim.width / 2, ePos.position.y + eDim.height / 2)
    love.graphics.rotate(eOri.orientation)
    love.graphics.draw(texture, -(eDim.width/2), -(eDim.height/2), 0, 
                       eDim.width / texture:getWidth(), 
                       eDim.height / texture:getHeight())
    love.graphics.pop()
    
    -- Dessiner des infos supplémentaires pour les mines
    if eResources and eTexture.name == "goldmine" then
        self:drawMineInfo(entity, ePos, eDim, eResources)
    end
    
    -- Remettre la couleur par défaut
    love.graphics.setColor(1, 1, 1, 1)
end

function World:drawMineInfo(entity, ePos, eDim, eResources)
    -- Afficher l'état de la mine au-dessus
    local stateText = ""
    if eResources.state == "full" then
        stateText = "⭐ Pleine"
    elseif eResources.state == "partial" then
        stateText = "◐ Partielle"
    elseif eResources.state == "low" then
        stateText = "◯ Faible"
    elseif eResources.state == "respawning" then
        local timeLeft = math.ceil(eResources.respawnTimer or 0)
        stateText = "⏳ " .. timeLeft .. "s"
    end
    
    if stateText ~= "" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(stateText, ePos.position.x - 10, ePos.position.y - 20)
    end
    
    -- Barre de progression de l'or
    local barWidth = eDim.width
    local barHeight = 4
    local barX = ePos.position.x
    local barY = ePos.position.y + eDim.height + 5
    
    -- Fond de la barre
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    
    -- Barre de progression
    local progress = eResources.goldAmount / eResources.maxGold
    love.graphics.setColor(1, 0.84, 0, 0.9) -- Doré
    love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight)
    
    -- Bordure
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
end

function World:updateMineState(mineId, mineData)
    -- Mettre à jour l'état d'une mine spécifique
    local mineEntity = self:getEntityById(mineId)
    if mineEntity and mineEntity.components["Resources"] then
        mineEntity.components["Resources"].goldAmount = mineData.goldAmount
        mineEntity.components["Resources"].maxGold = mineData.maxGold
        mineEntity.components["Resources"].state = mineData.state
        mineEntity.components["Resources"].respawnTimer = mineData.respawnTimer or 0
        
        print("[WORLD] Mine", mineId, "mise à jour:", mineData.goldAmount .. "/" .. mineData.maxGold, "État:", mineData.state)
    end
end

function World:addGoldAnimation(goldAmount)
    -- Animation simple de récolte d'or (optionnel pour plus tard)
    print("[ANIMATION] +", goldAmount, "or récolté!")
    -- TODO: Ajouter une vraie animation flottante
end

function World:updateNearbyMineIndicators(nearbyMines)
    -- Mettre à jour les indicateurs de mines proches
    self.nearbyMineIndicators = {}
    
    for mineId, mineData in pairs(nearbyMines or {}) do
        if mineData.canMine and mineData.goldAmount > 0 then
            local mineEntity = self:getEntityById(mineId)
            if mineEntity and mineEntity.components["Position"] and mineEntity.components["Dimension"] then
                local pos = mineEntity.components["Position"].position
                local dim = mineEntity.components["Dimension"]
                
                self.nearbyMineIndicators[mineId] = {
                    x = pos.x + dim.width / 2,
                    y = pos.y - 30,
                    state = mineData.state,
                    goldAmount = mineData.goldAmount,
                    maxGold = mineData.maxGold,
                    pulse = 0
                }
            end
        end
    end
end

function World:drawMineProximityIndicators()
    local time = love.timer and love.timer.getTime() or 0
    
    for mineId, indicator in pairs(self.nearbyMineIndicators) do
        -- Animation de pulsation
        local pulse = 0.8 + 0.2 * math.sin(time * 3)
        local alpha = 0.7 + 0.3 * math.sin(time * 2)
        
        -- Couleur selon l'état de la mine
        local color = {1, 0.84, 0, alpha} -- Doré par défaut
        if indicator.state == "partial" then
            color = {1, 0.9, 0.3, alpha}
        elseif indicator.state == "low" then
            color = {0.9, 0.8, 0.4, alpha}
        end
        
        love.graphics.setColor(color)
        
        -- Cercle pulsant
        love.graphics.circle("fill", indicator.x, indicator.y, 8 * pulse)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.circle("line", indicator.x, indicator.y, 8 * pulse)
        
        -- Icône "E" au centre
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.print("E", indicator.x - 4, indicator.y - 6)
        
        -- Flèche pointant vers la mine
        love.graphics.setColor(color)
        love.graphics.polygon("fill", 
            indicator.x, indicator.y + 10,
            indicator.x - 5, indicator.y + 15,
            indicator.x + 5, indicator.y + 15
        )
    end
    
    -- Remettre la couleur par défaut
    love.graphics.setColor(1, 1, 1, 1)
end

return World
