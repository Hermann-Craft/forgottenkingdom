local CharacterCreationScene = require(_G.libDir .. "middleclass")("CharacterCreationScene", _G.xle.Scene)
local TextInputElement = require(_G.engineDir .. "builtin.gameobjects.text-input")
local ButtonElement = require(_G.engineDir .. "builtin.gameobjects.button")
local LabelElement = require(_G.engineDir .. "builtin.gameobjects.label")
local DropdownElement = require(_G.engineDir .. "builtin.gameobjects.dropdown")
local SliderElement = require(_G.engineDir .. "builtin.gameobjects.slider")
local FormValidator = require(_G.libDir .. "form-validator")
local AuthManager = require(_G.libDir .. "auth-manager")

function CharacterCreationScene:initialize(name, active)
    _G.xle.Scene.initialize(self, name, active)
    
    -- Gestionnaire d'authentification
    if not _G.authManager then
        _G.authManager = AuthManager:new()
    end
    self.authManager = _G.authManager
    
    -- État de l'interface
    self.isLoading = false
    self.errorMessage = ""
    self.successMessage = ""
    self.currentStep = 1 -- 1: Nom, 2: Clan, 3: Stats, 4: Confirmation
    self.maxSteps = 4
    
    -- Données du personnage
    self.characterData = {
        name = "",
        clan = "",
        stats = {
            force = 10,
            intelligence = 10,
            speed = 10,
            agility = 10
        },
        totalStatPoints = 100
    }
    
    -- Configuration des clans
    self.clans = {
        {
            value = "Alliance",
            label = "Alliance",
            description = "Nobles guerriers unis pour la justice et l'honneur. Bonus: +2 Force, +1 Intelligence",
            bonuses = {force = 2, intelligence = 1, speed = 0, agility = 0},
            color = {0.3, 0.6, 1, 1}
        },
        {
            value = "Horde",
            label = "Horde",
            description = "Tribus sauvages maîtrisant la magie primitive. Bonus: +2 Intelligence, +1 Agility",
            bonuses = {force = 0, intelligence = 2, speed = 0, agility = 1},
            color = {1, 0.3, 0.3, 1}
        },
        {
            value = "Steampunk",
            label = "Steampunk",
            description = "Inventeurs utilisant la technologie à vapeur. Bonus: +2 Speed, +1 Force",
            bonuses = {force = 1, intelligence = 0, speed = 2, agility = 0},
            color = {0.8, 0.6, 0.2, 1}
        },
        {
            value = "Neutral",
            label = "Neutre",
            description = "Aventuriers libres sans allégeance. Bonus: +1 à toutes les stats",
            bonuses = {force = 1, intelligence = 1, speed = 1, agility = 1},
            color = {0.6, 0.6, 0.6, 1}
        }
    }
    
    -- Réponse adaptative
    self.screenWidth = 0
    self.screenHeight = 0
    
    print("[CHARACTER-CREATION] Scène de création de personnage initialisée")
end

function CharacterCreationScene:init()
    _G.xle.Scene.init(self)
    love.window.setTitle("Forgotten Kingdom - Création de personnage")
    
    -- Récupérer les dimensions écran
    self.screenWidth, self.screenHeight = love.graphics.getDimensions()
    
    -- Calculer les positions centrées
    local centerX = self.screenWidth / 2
    local centerY = self.screenHeight / 2
    local formWidth = 350
    local startY = centerY - 250
    
    -- Initialiser les éléments UI
    self.nodes = {
        -- Titre et navigation
        titleLabel = LabelElement:new("CRÉATION DE PERSONNAGE", centerX - 150, 50),
        stepLabel = LabelElement:new("Étape 1/4 - Nom du personnage", centerX - 100, 80),
        progressBar = {x = centerX - 200, y = 110, width = 400, height = 6},
        
        -- Étape 1: Nom du personnage
        nameLabel = LabelElement:new("Choisissez un nom pour votre personnage:", centerX - 150, startY),
        nameInput = TextInputElement:new(centerX - formWidth/2, startY + 30, formWidth, "Nom du personnage"),
        nameHelpLabel = LabelElement:new("Le nom doit contenir entre 2 et 16 lettres uniquement", centerX - 150, startY + 70),
        
        -- Étape 2: Sélection du clan
        clanLabel = LabelElement:new("Sélectionnez votre clan:", centerX - 80, startY),
        clanDropdown = DropdownElement:new(centerX - formWidth/2, startY + 30, formWidth, "Choisir un clan", {}),
        clanDescLabel = LabelElement:new("", centerX - 200, startY + 70),
        clanBonusLabel = LabelElement:new("", centerX - 150, startY + 100),
        
        -- Étape 3: Répartition des stats
        statsLabel = LabelElement:new("Répartissez vos points de statistiques:", centerX - 140, startY),
        pointsLabel = LabelElement:new("Points restants: 60", centerX - 60, startY + 30),
        
        -- Sliders des stats
        forceSlider = SliderElement:new(centerX - formWidth/2, startY + 70, formWidth - 50, 1, 40, 10, "Force"),
        intelligenceSlider = SliderElement:new(centerX - formWidth/2, startY + 120, formWidth - 50, 1, 40, 10, "Intelligence"),
        speedSlider = SliderElement:new(centerX - formWidth/2, startY + 170, formWidth - 50, 1, 40, 10, "Vitesse"),
        agilitySlider = SliderElement:new(centerX - formWidth/2, startY + 220, formWidth - 50, 1, 40, 10, "Agilité"),
        
        resetStatsButton = ButtonElement:new("Réinitialiser", centerX + 50, startY + 260),
        
        -- Étape 4: Aperçu et confirmation
        confirmLabel = LabelElement:new("Confirmer la création de votre personnage:", centerX - 150, startY),
        characterSummary = LabelElement:new("", centerX - 200, startY + 40),
        
        -- Boutons de navigation
        prevButton = ButtonElement:new("← Précédent", centerX - 120, self.screenHeight - 100, true),
        nextButton = ButtonElement:new("Suivant →", centerX + 20, self.screenHeight - 100, true),
        createButton = ButtonElement:new("Créer le personnage", centerX - 80, self.screenHeight - 100, true),
        cancelButton = ButtonElement:new("Annuler", centerX - 30, self.screenHeight - 60),
        
        -- Labels d'état
        statusLabel = LabelElement:new("", centerX - 150, self.screenHeight - 30),
        userInfoLabel = LabelElement:new("", 10, 10)
    }
    
    -- Configuration des éléments
    self:setupElements()
    self:setupEvents()
    self:updateStepVisibility()
    
    -- Charger les données utilisateur
    self:loadUserData()
end

function CharacterCreationScene:setupElements()
    -- Configuration du validateur pour le nom
    self.nodes.nameInput:setValidator(function(text)
        if not text or #text < 2 then
            return false, "Le nom doit contenir au moins 2 caractères"
        end
        if #text > 16 then
            return false, "Le nom ne peut pas dépasser 16 caractères"
        end
        if not string.match(text, "^[a-zA-Z]+$") then
            return false, "Le nom ne peut contenir que des lettres"
        end
        return true, "Nom valide"
    end)
    
    -- Configuration du dropdown des clans
    for _, clan in ipairs(self.clans) do
        self.nodes.clanDropdown:addOption(clan.value, clan.label)
    end
    
    -- Callback pour la sélection de clan
    self.nodes.clanDropdown:setOnSelect(function(value, label)
        print("[CHARACTER-CREATION] Clan sélectionné:", value, label)
        self.characterData.clan = value
        self:updateClanDescription()
        self:updateStepVisibility() -- Pour mettre à jour l'état du bouton suivant
    end)
    
    -- Configuration des sliders liés pour les stats
    local statSliders = {
        self.nodes.forceSlider,
        self.nodes.intelligenceSlider,
        self.nodes.speedSlider,
        self.nodes.agilitySlider
    }
    
    -- Callbacks pour les sliders de stats
    self.nodes.forceSlider:setOnChange(function(value)
        print("[CHARACTER-CREATION] Force changée:", value)
        self.characterData.stats.force = math.floor(value)
        self:updateStatsDisplay()
        self:updateStepVisibility()
    end)
    
    self.nodes.intelligenceSlider:setOnChange(function(value)
        print("[CHARACTER-CREATION] Intelligence changée:", value)
        self.characterData.stats.intelligence = math.floor(value)
        self:updateStatsDisplay()
        self:updateStepVisibility()
    end)
    
    self.nodes.speedSlider:setOnChange(function(value)
        print("[CHARACTER-CREATION] Vitesse changée:", value)
        self.characterData.stats.speed = math.floor(value)
        self:updateStatsDisplay()
        self:updateStepVisibility()
    end)
    
    self.nodes.agilitySlider:setOnChange(function(value)
        print("[CHARACTER-CREATION] Agilité changée:", value)
        self.characterData.stats.agility = math.floor(value)
        self:updateStatsDisplay()
        self:updateStepVisibility()
    end)
    
    -- Initialiser les stats avec les bonus de base
    self:resetStats()
end

function CharacterCreationScene:setupEvents()
    -- Navigation
    self.nodes.prevButton:addOnClickEvent("prev", function()
        self:previousStep()
    end)
    
    self.nodes.nextButton:addOnClickEvent("next", function()
        self:nextStep()
    end)
    
    self.nodes.createButton:addOnClickEvent("create", function()
        self:createCharacter()
    end)
    
    self.nodes.cancelButton:addOnClickEvent("cancel", function()
        self:cancel()
    end)
    
    -- Bouton de réinitialisation des stats
    self.nodes.resetStatsButton:addOnClickEvent("reset", function()
        self:resetStats()
    end)
    
    -- Événements de l'AuthManager pour la création de personnage
    self.authManager:onCharacterCreated(function(character)
        self.isLoading = false
        self.successMessage = "Personnage créé avec succès!"
        self:updateStatusLabel()
        
        -- Retourner à la scène de sélection après un délai
        love.timer.sleep(1)
        _G.xle.Scene.goToScene("scene-character-select")
    end)
    
    self.authManager:onCharacterCreationError(function(error)
        self.isLoading = false
        self.errorMessage = error
        self:updateStatusLabel()
    end)
    
    -- Événements spécifiques aux étapes
    self.nodes.nameInput:setOnEnter(function(text)
        if self.currentStep == 1 then
            self:nextStep()
        end
    end)
    
    self.nodes.clanDropdown:setOnSelect(function(value, label)
        self.characterData.clan = value
        self:updateClanDescription()
        self:applyClanBonuses()
    end)
    
    -- Stats
    self.nodes.forceSlider:setOnChange(function(value)
        self.characterData.stats.force = value
        self:updateStatsDisplay()
    end)
    
    self.nodes.intelligenceSlider:setOnChange(function(value)
        self.characterData.stats.intelligence = value
        self:updateStatsDisplay()
    end)
    
    self.nodes.speedSlider:setOnChange(function(value)
        self.characterData.stats.speed = value
        self:updateStatsDisplay()
    end)
    
    self.nodes.agilitySlider:setOnChange(function(value)
        self.characterData.stats.agility = value
        self:updateStatsDisplay()
    end)
    
    self.nodes.resetStatsButton:addOnClickEvent("reset", function()
        self:resetStats()
    end)
    
    -- Événements du gestionnaire d'authentification
    self.authManager:onCharacterCreated(function(character)
        self.isLoading = false
        self.successMessage = "Personnage créé avec succès!"
        self:updateStatusLabel()
        
        -- Retourner à la sélection de personnage
        love.timer.sleep(1)
        _G.xle.Scene.goToScene("scene-character-select")
    end)
    
    self.authManager:onCharacterCreationError(function(error)
        self.isLoading = false
        self.errorMessage = error
        self:updateStatusLabel()
    end)
end

function CharacterCreationScene:loadUserData()
    local user = self.authManager:getCurrentUser()
    if user then
        self.nodes.userInfoLabel.text:set("Connecté: " .. user.email)
    else
        -- Pas d'utilisateur connecté, retourner à la connexion
        print("[CHARACTER-CREATION] Aucun utilisateur connecté")
        _G.xle.Scene.goToScene("scene-login")
    end
end

function CharacterCreationScene:updateStepVisibility()
    -- Masquer tous les éléments d'étape
    local stepElements = {
        -- Étape 1
        {"nameLabel", "nameInput", "nameHelpLabel"},
        -- Étape 2
        {"clanLabel", "clanDropdown", "clanDescLabel", "clanBonusLabel"},
        -- Étape 3
        {"statsLabel", "pointsLabel", "forceSlider", "intelligenceSlider", "speedSlider", "agilitySlider", "resetStatsButton"},
        -- Étape 4
        {"confirmLabel", "characterSummary"}
    }
    
    -- Masquer tous les éléments
    for stepIndex, elements in ipairs(stepElements) do
        for _, elementName in ipairs(elements) do
            if self.nodes[elementName] then
                self.nodes[elementName].visible = false
            end
        end
    end
    
    -- Afficher les éléments de l'étape actuelle
    if stepElements[self.currentStep] then
        for _, elementName in ipairs(stepElements[self.currentStep]) do
            if self.nodes[elementName] then
                self.nodes[elementName].visible = true
            end
        end
    end
    
    -- Gérer la visibilité des boutons de navigation
    self.nodes.prevButton.visible = self.currentStep > 1
    self.nodes.prevButton.disabled = self.currentStep <= 1
    
    self.nodes.nextButton.visible = self.currentStep < self.maxSteps
    local canProceed = self:canProceedToNextStep()
    self.nodes.nextButton.disabled = not canProceed
    
    self.nodes.createButton.visible = self.currentStep == self.maxSteps
    self.nodes.createButton.disabled = not self:isDataValid()
    
    print("[CHARACTER-CREATION] Boutons - Précédent:", self.nodes.prevButton.visible, self.nodes.prevButton.disabled)
    print("[CHARACTER-CREATION] Boutons - Suivant:", self.nodes.nextButton.visible, self.nodes.nextButton.disabled, "canProceed:", canProceed)
    print("[CHARACTER-CREATION] Boutons - Créer:", self.nodes.createButton.visible, self.nodes.createButton.disabled)
    
    -- Mettre à jour le label d'étape
    local stepLabels = {
        "Étape 1/4 - Nom du personnage",
        "Étape 2/4 - Choix du clan",
        "Étape 3/4 - Répartition des stats",
        "Étape 4/4 - Confirmation"
    }
    
    self.nodes.stepLabel.text:set(stepLabels[self.currentStep] or "")
    
    -- Mise à jour spécifique selon l'étape
    if self.currentStep == 2 then
        self:updateClanDescription()
    elseif self.currentStep == 3 then
        self:updateStatsDisplay()
    elseif self.currentStep == 4 then
        self:updateCharacterSummary()
    end
end

function CharacterCreationScene:canProceedToNextStep()
    local canProceed = false
    local reason = ""
    
    if self.currentStep == 1 then
        local name = self.nodes.nameInput:getText()
        local isValid, validationMessage = self.nodes.nameInput:validate()
        canProceed = isValid and name ~= ""
        reason = not isValid and validationMessage or (name == "" and "Nom vide" or "OK")
        print("[CHARACTER-CREATION] Étape 1 - Nom:", name, "Valide:", isValid, "Raison:", reason)
    elseif self.currentStep == 2 then
        canProceed = self.characterData.clan ~= ""
        reason = canProceed and "OK" or "Aucun clan sélectionné"
        print("[CHARACTER-CREATION] Étape 2 - Clan:", self.characterData.clan, "Peut procéder:", canProceed)
    elseif self.currentStep == 3 then
        local totalUsed = self:getTotalStatsUsed()
        canProceed = totalUsed <= self.characterData.totalStatPoints
        reason = canProceed and "OK" or ("Total: " .. totalUsed .. "/" .. self.characterData.totalStatPoints)
        print("[CHARACTER-CREATION] Étape 3 - Stats total:", totalUsed, "Peut procéder:", canProceed)
    else
        canProceed = true
        reason = "OK"
    end
    
    print("[CHARACTER-CREATION] canProceedToNextStep - Étape:", self.currentStep, "Résultat:", canProceed, "Raison:", reason)
    return canProceed
end

function CharacterCreationScene:isDataValid()
    return self:canProceedToNextStep() and 
           self.characterData.name ~= "" and 
           self.characterData.clan ~= ""
end

function CharacterCreationScene:previousStep()
    if self.currentStep > 1 then
        self.currentStep = self.currentStep - 1
        self:updateStepVisibility()
    end
end

function CharacterCreationScene:nextStep()
    print("[CHARACTER-CREATION] nextStep appelé - Étape actuelle:", self.currentStep)
    
    if self.currentStep < self.maxSteps then
        if self:canProceedToNextStep() then
            -- Sauvegarder les données de l'étape actuelle
            if self.currentStep == 1 then
                self.characterData.name = self.nodes.nameInput:getText()
                print("[CHARACTER-CREATION] Nom sauvegardé:", self.characterData.name)
            elseif self.currentStep == 2 then
                print("[CHARACTER-CREATION] Clan confirmé:", self.characterData.clan)
            end
            
            self.currentStep = self.currentStep + 1
            print("[CHARACTER-CREATION] Passage à l'étape:", self.currentStep)
            self:updateStepVisibility()
        else
            print("[CHARACTER-CREATION] Impossible de procéder - validation échouée")
        end
    else
        print("[CHARACTER-CREATION] Déjà à la dernière étape")
    end
end

function CharacterCreationScene:updateClanDescription()
    local selectedClan = nil
    for _, clan in ipairs(self.clans) do
        if clan.value == self.characterData.clan then
            selectedClan = clan
            break
        end
    end
    
    if selectedClan then
        self.nodes.clanDescLabel.text:set(selectedClan.description)
        
        local bonusText = "Bonus: "
        local bonusParts = {}
        for stat, bonus in pairs(selectedClan.bonuses) do
            if bonus > 0 then
                table.insert(bonusParts, "+" .. bonus .. " " .. stat)
            end
        end
        bonusText = bonusText .. table.concat(bonusParts, ", ")
        self.nodes.clanBonusLabel.text:set(bonusText)
    else
        self.nodes.clanDescLabel.text:set("")
        self.nodes.clanBonusLabel.text:set("")
    end
end

function CharacterCreationScene:applyClanBonuses()
    local selectedClan = nil
    for _, clan in ipairs(self.clans) do
        if clan.value == self.characterData.clan then
            selectedClan = clan
            break
        end
    end
    
    if selectedClan then
        -- Réinitialiser aux valeurs de base puis ajouter les bonus
        self.characterData.stats.force = 10 + selectedClan.bonuses.force
        self.characterData.stats.intelligence = 10 + selectedClan.bonuses.intelligence
        self.characterData.stats.speed = 10 + selectedClan.bonuses.speed
        self.characterData.stats.agility = 10 + selectedClan.bonuses.agility
        
        -- Mettre à jour les sliders
        self.nodes.forceSlider:setValue(self.characterData.stats.force)
        self.nodes.intelligenceSlider:setValue(self.characterData.stats.intelligence)
        self.nodes.speedSlider:setValue(self.characterData.stats.speed)
        self.nodes.agilitySlider:setValue(self.characterData.stats.agility)
    end
end

function CharacterCreationScene:resetStats()
    -- Réinitialiser aux valeurs par défaut + bonus de clan
    if self.characterData.clan ~= "" then
        self:applyClanBonuses()
    else
        self.characterData.stats.force = 10
        self.characterData.stats.intelligence = 10
        self.characterData.stats.speed = 10
        self.characterData.stats.agility = 10
        
        self.nodes.forceSlider:setValue(10)
        self.nodes.intelligenceSlider:setValue(10)
        self.nodes.speedSlider:setValue(10)
        self.nodes.agilitySlider:setValue(10)
    end
    
    self:updateStatsDisplay()
end

function CharacterCreationScene:getTotalStatsUsed()
    return self.characterData.stats.force + 
           self.characterData.stats.intelligence + 
           self.characterData.stats.speed + 
           self.characterData.stats.agility
end

function CharacterCreationScene:updateStatsDisplay()
    local used = self:getTotalStatsUsed()
    local remaining = self.characterData.totalStatPoints - used
    
    self.nodes.pointsLabel.text:set("Points restants: " .. remaining)
    
    -- Désactiver les sliders si plus de points
    local canIncrease = remaining > 0
    
    -- Chaque slider peut être augmenté seulement si on a des points restants
    -- ou diminué si au-dessus du minimum
    -- Cette logique sera affinée selon les besoins
end

function CharacterCreationScene:updateCharacterSummary()
    local summary = string.format(
        "Nom: %s\nClan: %s\n\nStatistiques:\nForce: %d\nIntelligence: %d\nVitesse: %d\nAgilité: %d\n\nTotal des points utilisés: %d/%d",
        self.characterData.name,
        self.characterData.clan,
        self.characterData.stats.force,
        self.characterData.stats.intelligence,
        self.characterData.stats.speed,
        self.characterData.stats.agility,
        self:getTotalStatsUsed(),
        self.characterData.totalStatPoints
    )
    
    self.nodes.characterSummary.text:set(summary)
end

function CharacterCreationScene:createCharacter()
    if not self:isDataValid() then
        self.errorMessage = "Veuillez vérifier toutes les informations"
        self:updateStatusLabel()
        return
    end
    
    self.isLoading = true
    self:updateStatusLabel()
    
    -- Préparer les données pour l'envoi
    local characterData = {
        name = self.characterData.name,
        clan = self.characterData.clan,
        stats = self.characterData.stats
    }
    
    -- Créer le personnage via l'AuthManager
    self.authManager:createCharacter(characterData)
end

function CharacterCreationScene:cancel()
    _G.xle.Scene.goToScene("scene-character-select")
end

function CharacterCreationScene:updateStatusLabel()
    local text = ""
    if self.isLoading then
        text = "Création en cours..."
    elseif self.errorMessage ~= "" then
        text = self.errorMessage
    elseif self.successMessage ~= "" then
        text = self.successMessage
    end
    
    self.nodes.statusLabel.text:set(text)
end

function CharacterCreationScene:update(dt, ...)
    -- Mettre à jour l'AuthManager
    self.authManager:update(dt)
    
    -- Mettre à jour les éléments UI
    for k, node in pairs(self.nodes) do
        if node and node.update and (node.visible ~= false) then
            node:update(dt, ...)
        end
    end
    
    -- Mettre à jour le label de statut
    self:updateStatusLabel()
end

function CharacterCreationScene:draw(...)
    -- Fond dégradé
    love.graphics.setColor(0.05, 0.05, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    
    -- Barre de progression
    local progress = self.nodes.progressBar
    local progressPercent = (self.currentStep - 1) / (self.maxSteps - 1)
    
    -- Fond de la barre
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.rectangle("fill", progress.x, progress.y, progress.width, progress.height)
    
    -- Progression
    love.graphics.setColor(0.3, 0.6, 1, 1)
    love.graphics.rectangle("fill", progress.x, progress.y, progress.width * progressPercent, progress.height)
    
    -- Bordure
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", progress.x, progress.y, progress.width, progress.height)
    
    -- Dessiner les éléments UI visibles
    for k, node in pairs(self.nodes) do
        if node and node.draw and (node.visible ~= false) then
            -- Colorer selon le type d'élément
            if k == "titleLabel" then
                love.graphics.setColor(1, 0.8, 0.2, 1)
            elseif k == "stepLabel" then
                love.graphics.setColor(0.8, 0.8, 1, 1)
            elseif k == "statusLabel" then
                if self.errorMessage ~= "" then
                    love.graphics.setColor(1, 0.3, 0.3, 1)
                elseif self.successMessage ~= "" then
                    love.graphics.setColor(0.3, 1, 0.3, 1)
                else
                    love.graphics.setColor(1, 1, 1, 1)
                end
            elseif k == "userInfoLabel" then
                love.graphics.setColor(0.6, 0.6, 0.6, 1)
            elseif k == "clanDescLabel" then
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
            elseif k == "clanBonusLabel" then
                love.graphics.setColor(0.3, 1, 0.3, 1)
            elseif k == "characterSummary" then
                love.graphics.setColor(0.9, 0.9, 1, 1)
            elseif k == "nameHelpLabel" then
                love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
            else
                love.graphics.setColor(1, 1, 1, 1)
            end
            
            node:draw(...)
        end
    end
    
    -- Indicateur de chargement
    if self.isLoading then
        love.graphics.setColor(1, 1, 1, 0.8)
        local centerX = self.screenWidth / 2
        local centerY = self.screenHeight / 2
        love.graphics.circle("line", centerX, centerY + 50, 10 + math.sin(love.timer.getTime() * 5) * 5)
    end
    
    -- Remettre la couleur par défaut
    love.graphics.setColor(1, 1, 1, 1)
end

function CharacterCreationScene:mousepressed(x, y, button, ...)
    local handled = false
    for k, node in pairs(self.nodes) do
        if node and node.mousepressed and (node.visible ~= false) then
            if node:mousepressed(x, y, button, ...) then
                handled = true
                break
            end
        end
    end
    
    -- Si aucun élément n'a traité le clic, défocuser les champs de texte
    if not handled and _G.textInputFocused then
        _G.textInputFocused:blur()
    end
end

function CharacterCreationScene:mousereleased(x, y, button, ...)
    for k, node in pairs(self.nodes) do
        if node and node.mousereleased and (node.visible ~= false) then
            node:mousereleased(x, y, button, ...)
        end
    end
end

function CharacterCreationScene:mousemoved(x, y, ...)
    for k, node in pairs(self.nodes) do
        if node and node.mousemoved and (node.visible ~= false) then
            node:mousemoved(x, y, ...)
        end
    end
end

function CharacterCreationScene:textinput(text)
    for k, node in pairs(self.nodes) do
        if node and node.textinput and (node.visible ~= false) then
            node:textinput(text)
        end
    end
end

function CharacterCreationScene:keypressed(key)
    for k, node in pairs(self.nodes) do
        if node and node.keypressed and (node.visible ~= false) then
            if node:keypressed(key) then
                return -- Un élément a traité la touche
            end
        end
    end
    
    -- Échapper pour annuler
    if key == "escape" then
        self:cancel()
    end
end

return CharacterCreationScene 
