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
        miningCooldown = 2, -- Cooldown visuel en secondes
        
        -- Menu contextuel des villageois
        villagerMenuOpen = false,
        villagerMenuData = nil,
        villagerMenuPosition = {x = 0, y = 0},
        selectedTaskIndex = 1
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

function UIManager:drawVillagerInterface(villagerInfo, screenWidth, screenHeight)
    -- Dessiner le panneau principal de l'or
    self:drawGoldPanel(villagerInfo, screenWidth, screenHeight)
    
    -- Dessiner l'indicateur de villageois si applicable
    if villagerInfo.hasAvailableVillagers then
        self:drawVillagerIndicator(villagerInfo, screenWidth, screenHeight)
    end
    
    -- Dessiner le menu contextuel du villageois si ouvert
    if self.uiState.villagerMenuOpen then
        self:drawVillagerMenu(screenWidth, screenHeight)
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

function UIManager:drawVillagerIndicator(villagerInfo, screenWidth, screenHeight)
    local panelX = screenWidth - 180
    local panelY = 60
    local panelW = 170
    local baseH = 30
    
    -- Calculer la hauteur nécessaire
    local villagerCount = 0
    for villagerId, villagerData in pairs(villagerInfo.nearbyVillagers) do
        if villagerData.canRecruit or villagerData.canMenu then
            villagerCount = villagerCount + 1
        end
    end
    
    local panelH = baseH + (villagerCount * 22)
    
    -- Fond du panneau
    love.graphics.setColor(self.style.panelBg)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 5, 5)
    
    -- Bordure
    love.graphics.setColor(self.style.panelBorder)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 5, 5)
    
    -- Indicateur de touche E avec animation
    local canInteract = self.uiState.lastMiningAttempt <= 0
    local keyColor = canInteract and {0.2, 0.8, 0.2, 1} or self.style.warningColor -- Vert pour villageois
    
    love.graphics.setColor(keyColor)
    local pulseAlpha = canInteract and (0.7 + 0.3 * math.sin(love.timer.getTime() * 4)) or 0.5
    love.graphics.setColor(keyColor[1], keyColor[2], keyColor[3], pulseAlpha)
    
    -- Encadré de la touche E
    love.graphics.rectangle("fill", panelX + 8, panelY + 8, 20, 16, 2, 2)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("E", panelX + 15, panelY + 9)
    
    -- Texte selon le type d'interaction
    local actionText = "Recruter"
    local hasWorkers = false
    for villagerId, villagerData in pairs(villagerInfo.nearbyVillagers) do
        if villagerData.canMenu then
            actionText = "Menu"
            hasWorkers = true
            break
        end
    end
    
    love.graphics.setColor(self.style.textColor)
    love.graphics.print(actionText, panelX + 35, panelY + 9)
    
    -- Cooldown si applicable
    if self.uiState.lastMiningAttempt > 0 then
        local cooldownText = string.format("%.1fs", self.uiState.lastMiningAttempt)
        love.graphics.setColor(self.style.warningColor)
        love.graphics.print(cooldownText, panelX + 90, panelY + 9)
    end
    
    -- Liste des villageois proches
    local yOffset = 28
    for villagerId, villagerData in pairs(villagerInfo.nearbyVillagers) do
        if villagerData.canRecruit or villagerData.canMenu then
            -- Icône selon le type de villageois
            local stateIcon = "👤"
            local stateColor = {0.2, 0.8, 0.2, 1} -- Vert pour villageois
            
            if villagerData.type == "Worker" then
                stateIcon = "⚒️"
                stateColor = {0.2, 0.6, 0.8, 1} -- Bleu pour workers
            elseif villagerData.canRecruit then
                stateIcon = "💰"
                stateColor = {0.2, 0.8, 0.2, 1} -- Vert pour recrutement
            end
            
            love.graphics.setColor(stateColor)
            love.graphics.print(stateIcon, panelX + 8, panelY + yOffset)
            
            -- Texte des infos du villageois
            love.graphics.setColor(self.style.textColor)
            local villagerText = ""
            if villagerData.canRecruit then
                local costText = string.format("Coût: %d or", villagerData.cost or 25)
                local affordText = ""
                if villagerData.canAfford == false then
                    affordText = " (Pas assez d'or)"
                    love.graphics.setColor(self.style.errorColor)
                end
                villagerText = costText .. affordText
            elseif villagerData.canMenu then
                if villagerData.isOwner then
                    villagerText = "Votre villageois"
                else
                    villagerText = "Villageois d'un autre clan"
                    love.graphics.setColor(self.style.warningColor)
                end
            end
            love.graphics.print(villagerText, panelX + 25, panelY + yOffset)
            
            -- Deuxième ligne avec nom/stats si disponibles
            if villagerData.villagerName then
                love.graphics.setColor(0.8, 0.8, 0.8, 1)
                local nameText = "Nom: " .. villagerData.villagerName
                love.graphics.print(nameText, panelX + 25, panelY + yOffset + 10)
                yOffset = yOffset + 22
            elseif villagerData.stats and villagerData.stats.task then
                love.graphics.setColor(0.8, 0.8, 0.8, 1)
                local taskText = "Tâche: " .. (villagerData.stats.task or "Idle")
                love.graphics.print(taskText, panelX + 25, panelY + yOffset + 10)
                yOffset = yOffset + 22
            else
                yOffset = yOffset + 22
            end
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

-- Méthodes pour la gestion des villageois

function UIManager:onRecruitmentAttempt()
    self.uiState.lastMiningAttempt = self.uiState.miningCooldown
end

function UIManager:onRecruitmentSuccess(cost, villagerName)
    local message = "Villageois recruté! -" .. cost .. " or"
    if villagerName then
        message = villagerName .. " recruté! -" .. cost .. " or"
    end
    self:addNotification(message, "success", 3)
end

function UIManager:onRecruitmentError(message)
    self:addNotification(message, "error", 3)
end

-- ===== MENU CONTEXTUEL VILLAGEOIS =====

function UIManager:openVillagerMenu(menuData)
    -- Ouvrir le menu contextuel avec les données du villageois
    self.uiState.villagerMenuOpen = true
    self.uiState.villagerMenuData = menuData
    self.uiState.selectedTaskIndex = 1
    
    -- Positionner le menu au centre de l'écran
    self.uiState.villagerMenuPosition = {
        x = love.graphics.getWidth() / 2 - 150,
        y = love.graphics.getHeight() / 2 - 100
    }
    
    print("[UI] Menu contextuel ouvert pour:", menuData.villagerName)
end

function UIManager:closeVillagerMenu()
    -- Envoyer message de fermeture au serveur si un menu était ouvert
    if self.uiState.villagerMenuOpen and self.uiState.villagerMenuData and self.uiState.villagerMenuData.villagerId then
        if _G.worldServer then
            _G.worldServer.tcp:send(_G.bitser.dumps({
                id = "player_close_villager_menu",
                data = {
                    villagerId = self.uiState.villagerMenuData.villagerId
                }
            }))
            print("[UI] Message de fermeture envoyé pour villageois:", self.uiState.villagerMenuData.villagerId)
        end
    end
    
    -- Fermer le menu contextuel
    self.uiState.villagerMenuOpen = false
    self.uiState.villagerMenuData = nil
    print("[UI] Menu contextuel fermé")
end

function UIManager:drawVillagerMenu(screenWidth, screenHeight)
    if not self.uiState.villagerMenuData then
        return
    end
    
    local menuData = self.uiState.villagerMenuData
    local pos = self.uiState.villagerMenuPosition
    
    -- Dimensions du menu
    local menuW = 300
    local menuH = 50 + (#menuData.availableTasks * 35) + 40 -- Header + tâches + footer
    
    -- Fond semi-transparent pour bloquer les interactions derrière
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Fond du menu
    love.graphics.setColor(0.15, 0.15, 0.15, 0.95)
    love.graphics.rectangle("fill", pos.x, pos.y, menuW, menuH, 8, 8)
    
    -- Bordure du menu
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.rectangle("line", pos.x, pos.y, menuW, menuH, 8, 8)
    
    -- En-tête du menu
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Menu de " .. menuData.villagerName, pos.x + 15, pos.y + 15)
    
    -- Tâche actuelle
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local currentTaskText = "Tâche actuelle: " .. menuData.currentTask
    love.graphics.print(currentTaskText, pos.x + 15, pos.y + 30)
    
    -- Liste des tâches disponibles
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Assigner une nouvelle tâche:", pos.x + 15, pos.y + 55)
    
    for i, task in ipairs(menuData.availableTasks) do
        local taskY = pos.y + 75 + ((i - 1) * 35)
        local isSelected = (i == self.uiState.selectedTaskIndex)
        local isDisabled = task.disabled == true  -- Utiliser task.disabled au lieu de not task.enabled
        
        -- Fond de la tâche sélectionnée
        if isSelected and not isDisabled then
            love.graphics.setColor(0.3, 0.5, 0.8, 0.7)
            love.graphics.rectangle("fill", pos.x + 10, taskY - 2, menuW - 20, 30, 4, 4)
        end
        
        -- Couleur du texte selon l'état
        if isDisabled then
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
        elseif isSelected then
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
        end
        
        -- Icône et nom de la tâche - utiliser task.id au lieu de task.taskId et task.name directement
        local taskIcon = self:getTaskIcon(task.id)
        local taskName = task.name or self:getTaskDisplayName(task.id)
        local taskText = taskIcon .. " " .. taskName
        
        if isDisabled and task.disabledReason then
            taskText = taskText .. " (" .. task.disabledReason .. ")"
        end
        
        love.graphics.print(taskText, pos.x + 20, taskY + 5)
        
        -- Indicateur de sélection
        if isSelected and not isDisabled then
            love.graphics.setColor(0.2, 0.8, 0.2, 1)
            love.graphics.print("→", pos.x + 5, taskY + 5)
        end
    end
    
    -- Instructions en bas
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local instructionY = pos.y + menuH - 30
    love.graphics.print("↑↓ Naviguer  ENTRÉE Assigner  ÉCHAP Fermer", pos.x + 15, instructionY)
end

function UIManager:getTaskIcon(taskId)
    local icons = {
        [0] = "💤", -- Idle
        [1] = "👥", -- Follow
        [2] = "🪓", -- ChopWood
        [3] = "⛏️", -- MineGold
        [4] = "⚔️"  -- Defend
    }
    return icons[taskId] or "❓"
end

function UIManager:getTaskDisplayName(taskId)
    local names = {
        [0] = "Repos",
        [1] = "Suivre",
        [2] = "Couper du bois",
        [3] = "Miner de l'or",
        [4] = "Défendre"
    }
    return names[taskId] or "Inconnu"
end

function UIManager:onTaskAssignmentSuccess(newTask, villagerName)
    local taskName = self:getTaskDisplayName(newTask)
    local message = "Tâche assignée: " .. taskName
    if villagerName then
        message = villagerName .. " - " .. message
    end
    self:addNotification(message, "success", 3)
    self:closeVillagerMenu()
end

-- Navigation du menu (à appeler depuis scene-play.lua)
function UIManager:navigateMenuUp()
    if not self.uiState.villagerMenuOpen or not self.uiState.villagerMenuData then
        return false
    end
    
    local enabledTasks = {}
    for i, task in ipairs(self.uiState.villagerMenuData.availableTasks) do
        if not task.disabled then  -- Changer task.enabled vers not task.disabled
            table.insert(enabledTasks, i)
        end
    end
    
    if #enabledTasks > 0 then
        local currentPos = 1
        for i, taskIndex in ipairs(enabledTasks) do
            if taskIndex == self.uiState.selectedTaskIndex then
                currentPos = i
                break
            end
        end
        
        currentPos = currentPos - 1
        if currentPos < 1 then
            currentPos = #enabledTasks
        end
        
        self.uiState.selectedTaskIndex = enabledTasks[currentPos]
    end
    
    return true
end

function UIManager:navigateMenuDown()
    if not self.uiState.villagerMenuOpen or not self.uiState.villagerMenuData then
        return false
    end
    
    local enabledTasks = {}
    for i, task in ipairs(self.uiState.villagerMenuData.availableTasks) do
        if not task.disabled then  -- Changer task.enabled vers not task.disabled
            table.insert(enabledTasks, i)
        end
    end
    
    if #enabledTasks > 0 then
        local currentPos = 1
        for i, taskIndex in ipairs(enabledTasks) do
            if taskIndex == self.uiState.selectedTaskIndex then
                currentPos = i
                break
            end
        end
        
        currentPos = currentPos + 1
        if currentPos > #enabledTasks then
            currentPos = 1
        end
        
        self.uiState.selectedTaskIndex = enabledTasks[currentPos]
    end
    
    return true
end

function UIManager:selectCurrentTask()
    if not self.uiState.villagerMenuOpen or not self.uiState.villagerMenuData then
        return false
    end
    
    local selectedTask = self.uiState.villagerMenuData.availableTasks[self.uiState.selectedTaskIndex]
    if selectedTask and not selectedTask.disabled then  -- Changer selectedTask.enabled vers not selectedTask.disabled
        -- Envoyer la demande d'assignation via WorldServer
        if _G.worldServer then
            _G.worldServer:assignTaskToVillager(
                self.uiState.villagerMenuData.villagerId,
                selectedTask.id  -- Utiliser selectedTask.id au lieu de selectedTask.taskId
            )
        end
        return true
    end
    
    return false
end

function UIManager:isMenuOpen()
    return self.uiState.villagerMenuOpen
end

return UIManager 
