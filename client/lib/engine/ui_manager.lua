local UIManager = require(_G.libDir .. "middleclass")("UIManager")

function UIManager:initialize()
    -- Notifications flottantes
    self.notifications = {}
    self.maxNotifications = 5
    
    -- Animations de l'or
    self.goldAnimations = {}
    
    -- État de l'interface
    self.uiState = {
        showMiningPanel = false,
        lastMiningAttempt = 0,
        miningCooldown = 2 -- Cooldown visuel en secondes
    }
    
    -- Style de l'interface
    self.style = {
        panelBg = {0.1, 0.1, 0.1, 0.8},
        panelBorder = {0.4, 0.4, 0.4, 1},
        goldColor = {1, 0.84, 0, 1},
        successColor = {0.2, 0.8, 0.2, 1},
        errorColor = {0.8, 0.2, 0.2, 1},
        warningColor = {1, 0.8, 0.2, 1},
        textColor = {1, 1, 1, 1}
    }
end

function UIManager:update(dt)
    -- Mettre à jour les notifications
    for i = #self.notifications, 1, -1 do
        local notif = self.notifications[i]
        notif.timer = notif.timer - dt
        notif.y = notif.y - 20 * dt -- Animation vers le haut
        notif.alpha = math.max(0, notif.alpha - dt * 0.5)
        
        if notif.timer <= 0 or notif.alpha <= 0 then
            table.remove(self.notifications, i)
        end
    end
    
    -- Mettre à jour les animations d'or
    for i = #self.goldAnimations, 1, -1 do
        local anim = self.goldAnimations[i]
        anim.timer = anim.timer - dt
        anim.y = anim.y - 30 * dt -- Animation vers le haut
        anim.alpha = math.max(0, anim.alpha - dt * 2)
        
        if anim.timer <= 0 or anim.alpha <= 0 then
            table.remove(self.goldAnimations, i)
        end
    end
    
    -- Mettre à jour le cooldown de mining
    if self.uiState.lastMiningAttempt > 0 then
        self.uiState.lastMiningAttempt = self.uiState.lastMiningAttempt - dt
        if self.uiState.lastMiningAttempt < 0 then
            self.uiState.lastMiningAttempt = 0
        end
    end
end

function UIManager:drawMiningInterface(miningInfo, screenWidth, screenHeight)
    -- Dessiner le panneau principal de l'or
    self:drawGoldPanel(miningInfo, screenWidth, screenHeight)
    
    -- Dessiner l'indicateur de mining si applicable
    if miningInfo.hasAvailableMines then
        self:drawMiningIndicator(miningInfo, screenWidth, screenHeight)
    end
    
    -- Dessiner les notifications
    self:drawNotifications(screenWidth, screenHeight)
    
    -- Dessiner les animations d'or
    self:drawGoldAnimations()
end

function UIManager:drawGoldPanel(miningInfo, screenWidth, screenHeight)
    local panelX = screenWidth - 180
    local panelY = 10
    local panelW = 170
    local panelH = 40
    
    -- Fond du panneau
    love.graphics.setColor(self.style.panelBg)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 5, 5)
    
    -- Bordure
    love.graphics.setColor(self.style.panelBorder)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 5, 5)
    
    -- Icône de l'or
    love.graphics.setColor(self.style.goldColor)
    love.graphics.print("💰", panelX + 8, panelY + 8)
    
    -- Texte de l'or
    local goldText = "Or: " .. miningInfo.playerGold .. "/" .. miningInfo.maxGold
    love.graphics.setColor(self.style.goldColor)
    love.graphics.print(goldText, panelX + 28, panelY + 8)
    
    -- Barre de progression du wallet
    local barX = panelX + 8
    local barY = panelY + 25
    local barW = panelW - 16
    local barH = 6
    
    -- Fond de la barre
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 2, 2)
    
    -- Progression
    local progress = miningInfo.playerGold / miningInfo.maxGold
    love.graphics.setColor(self.style.goldColor)
    love.graphics.rectangle("fill", barX, barY, barW * progress, barH, 2, 2)
    
    -- Bordure de la barre
    love.graphics.setColor(self.style.panelBorder)
    love.graphics.rectangle("line", barX, barY, barW, barH, 2, 2)
end

function UIManager:drawMiningIndicator(miningInfo, screenWidth, screenHeight)
    local panelX = screenWidth - 180
    local panelY = 60
    local panelW = 170
    local baseH = 30
    
    -- Calculer la hauteur nécessaire
    local mineCount = 0
    for mineId, mineData in pairs(miningInfo.nearbyMines) do
        if mineData.canMine and mineData.goldAmount > 0 then
            mineCount = mineCount + 1
        end
    end
    
    local panelH = baseH + (mineCount * 18)
    
    -- Fond du panneau
    love.graphics.setColor(self.style.panelBg)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 5, 5)
    
    -- Bordure
    love.graphics.setColor(self.style.panelBorder)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 5, 5)
    
    -- Indicateur de touche E avec animation
    local canMine = self.uiState.lastMiningAttempt <= 0
    local keyColor = canMine and self.style.successColor or self.style.warningColor
    
    love.graphics.setColor(keyColor)
    local pulseAlpha = canMine and (0.7 + 0.3 * math.sin(love.timer.getTime() * 4)) or 0.5
    love.graphics.setColor(keyColor[1], keyColor[2], keyColor[3], pulseAlpha)
    
    -- Encadré de la touche E
    love.graphics.rectangle("fill", panelX + 8, panelY + 8, 20, 16, 2, 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("E", panelX + 15, panelY + 9)
    
    -- Texte "Miner"
    love.graphics.setColor(self.style.textColor)
    love.graphics.print("Miner", panelX + 35, panelY + 9)
    
    -- Cooldown si applicable
    if self.uiState.lastMiningAttempt > 0 then
        local cooldownText = string.format("%.1fs", self.uiState.lastMiningAttempt)
        love.graphics.setColor(self.style.warningColor)
        love.graphics.print(cooldownText, panelX + 80, panelY + 9)
    end
    
    -- Liste des mines proches
    local yOffset = 28
    for mineId, mineData in pairs(miningInfo.nearbyMines) do
        if mineData.canMine and mineData.goldAmount > 0 then
            -- Icône selon l'état de la mine
            local stateIcon = "⭐"
            local stateColor = self.style.goldColor
            
            if mineData.state == "partial" then
                stateIcon = "◐"
                stateColor = {1, 0.9, 0.3, 1}
            elseif mineData.state == "low" then
                stateIcon = "◯"
                stateColor = {0.9, 0.8, 0.4, 1}
            end
            
            love.graphics.setColor(stateColor)
            love.graphics.print(stateIcon, panelX + 8, panelY + yOffset)
            
            -- Texte des infos de la mine
            love.graphics.setColor(self.style.textColor)
            local mineText = string.format("Mine: %d/%d", mineData.goldAmount, mineData.maxGold)
            love.graphics.print(mineText, panelX + 25, panelY + yOffset)
            
            yOffset = yOffset + 18
        end
    end
end

function UIManager:drawNotifications(screenWidth, screenHeight)
    for i, notif in ipairs(self.notifications) do
        love.graphics.setColor(notif.color[1], notif.color[2], notif.color[3], notif.alpha)
        
        -- Fond de la notification
        local textWidth = love.graphics.getFont():getWidth(notif.text)
        local notifX = screenWidth - textWidth - 20
        local notifY = notif.y
        
        love.graphics.setColor(0.1, 0.1, 0.1, notif.alpha * 0.8)
        love.graphics.rectangle("fill", notifX - 5, notifY - 2, textWidth + 10, 20, 3, 3)
        
        -- Texte
        love.graphics.setColor(notif.color[1], notif.color[2], notif.color[3], notif.alpha)
        love.graphics.print(notif.text, notifX, notifY)
    end
end

function UIManager:drawGoldAnimations()
    for _, anim in ipairs(self.goldAnimations) do
        love.graphics.setColor(self.style.goldColor[1], self.style.goldColor[2], self.style.goldColor[3], anim.alpha)
        love.graphics.print("+" .. anim.amount .. " or", anim.x, anim.y)
    end
end

function UIManager:addNotification(text, type, duration)
    type = type or "info"
    duration = duration or 3
    
    local color = self.style.textColor
    if type == "success" then
        color = self.style.successColor
    elseif type == "error" then
        color = self.style.errorColor
    elseif type == "warning" then
        color = self.style.warningColor
    end
    
    -- Décaler les notifications existantes vers le haut
    for _, notif in ipairs(self.notifications) do
        notif.y = notif.y - 25
    end
    
    -- Ajouter la nouvelle notification
    table.insert(self.notifications, {
        text = text,
        color = color,
        timer = duration,
        alpha = 1,
        y = love.graphics.getHeight() - 100
    })
    
    -- Limiter le nombre de notifications
    if #self.notifications > self.maxNotifications then
        table.remove(self.notifications, 1)
    end
end

function UIManager:addGoldAnimation(amount, x, y)
    table.insert(self.goldAnimations, {
        amount = amount,
        x = x or love.graphics.getWidth() - 100,
        y = y or 50,
        timer = 2,
        alpha = 1
    })
end

function UIManager:onMiningAttempt()
    self.uiState.lastMiningAttempt = self.uiState.miningCooldown
end

function UIManager:onMiningSuccess(amount)
    self:addNotification("+" .. amount .. " or récolté!", "success", 2)
    self:addGoldAnimation(amount)
end

function UIManager:onMiningError(message)
    self:addNotification(message, "error", 3)
end

return UIManager 
