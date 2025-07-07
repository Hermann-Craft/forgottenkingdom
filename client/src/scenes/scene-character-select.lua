local CharacterSelectScene = require(_G.libDir .. "middleclass")("CharacterSelectScene", _G.xle.Scene)
local TextInputElement = require(_G.engineDir .. "builtin.gameobjects.text-input")
local ButtonElement = require(_G.engineDir .. "builtin.gameobjects.button")
local LabelElement = require(_G.engineDir .. "builtin.gameobjects.label")
local FormValidator = require(_G.libDir .. "form-validator")
local AuthManager = require(_G.libDir .. "auth-manager")

function CharacterSelectScene:initialize(name, active)
    _G.xle.Scene.initialize(self, name, active)
    
    -- Gestionnaire d'authentification (instance globale)
    if not _G.authManager then
        _G.authManager = AuthManager:new()
    end
    self.authManager = _G.authManager
    
    -- État de l'interface
    self.isLoading = false
    self.errorMessage = ""
    self.successMessage = ""
    self.showQuickCreate = false
    
    -- Données utilisateur
    self.characters = {}
    self.selectedCharacter = nil
    self.selectedCharacterIndex = 0
    
    -- Configuration des couleurs de clan
    self.clanColors = {
        Alliance = {0.3, 0.6, 1, 1},
        Horde = {1, 0.3, 0.3, 1},
        Steampunk = {0.8, 0.6, 0.2, 1},
        Neutral = {0.6, 0.6, 0.6, 1}
    }
    
    -- Réponse adaptative
    self.screenWidth = 0
    self.screenHeight = 0
    
    print("[CHARACTER-SELECT] Scène de sélection de personnage initialisée")
end

function CharacterSelectScene:init()
    _G.xle.Scene.init(self)
    love.window.setTitle("Forgotten Kingdom - Sélection de personnage")
    
    -- Récupérer les dimensions écran
    self.screenWidth, self.screenHeight = love.graphics.getDimensions()
    
    -- Calculer les positions centrées
    local centerX = self.screenWidth / 2
    local centerY = self.screenHeight / 2
    local formWidth = 300
    local startY = centerY - 250
    
    -- Initialiser les éléments UI
    self.nodes = {
        -- Titre et info utilisateur
        titleLabel = LabelElement:new("FORGOTTEN KINGDOM", centerX - 120, 30),
        subtitleLabel = LabelElement:new("Sélectionner un personnage", centerX - 100, 65),
        userInfoLabel = LabelElement:new("", 20, 20),
        
        -- Zone de sélection de personnage (à gauche)
        characterListLabel = LabelElement:new("Vos personnages:", 50, startY),
        
        -- Aperçu du personnage sélectionné (à droite)
        previewLabel = LabelElement:new("Aperçu", centerX + 100, startY),
        previewDetails = LabelElement:new("Sélectionnez un personnage\npour voir ses détails", centerX + 100, startY + 30),
        
        -- Boutons d'action principaux (en bas, bien espacés)
        createAdvancedButton = ButtonElement:new("Créer un personnage", centerX - 200, self.screenHeight - 120),
        quickCreateButton = ButtonElement:new("Création rapide", centerX - 50, self.screenHeight - 120),
        playButton = ButtonElement:new("Jouer", centerX + 100, self.screenHeight - 120, true),
        deleteButton = ButtonElement:new("Supprimer", centerX + 200, self.screenHeight - 120, true),
        logoutButton = ButtonElement:new("Déconnexion", centerX - 50, self.screenHeight - 80),
        
        -- Formulaire de création rapide (caché par défaut)
        quickCreateLabel = LabelElement:new("Création rapide de personnage", centerX - 110, centerY - 50),
        quickNameInput = TextInputElement:new(centerX - formWidth/2, centerY - 20, formWidth, "Nom du personnage"),
        quickCreateConfirmButton = ButtonElement:new("Créer", centerX - 60, centerY + 20),
        quickCancelButton = ButtonElement:new("Annuler", centerX + 10, centerY + 20),
        
        -- Labels d'état
        statusLabel = LabelElement:new("", centerX - 150, self.screenHeight - 50),
        helpLabel = LabelElement:new("Sélectionnez un personnage ou créez-en un nouveau", centerX - 140, self.screenHeight - 25)
    }
    
    -- Configuration des validateurs
    self.nodes.quickNameInput:setValidator(function(text)
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
    
    -- Configuration des événements
    self:setupEvents()
    
    -- Charger les données utilisateur
    self:loadUserData()
    
    -- Initialiser la visibilité des éléments
    self:updateUIVisibility()
end

function CharacterSelectScene:setupEvents()
    -- Événements des boutons principaux
    self.nodes.createAdvancedButton:addOnClickEvent("create_advanced", function()
        self:openAdvancedCreation()
    end)
    
    self.nodes.quickCreateButton:addOnClickEvent("quick_create", function()
        self:showQuickCreateForm()
    end)
    
    self.nodes.playButton:addOnClickEvent("play", function()
        self:playSelectedCharacter()
    end)
    
    self.nodes.deleteButton:addOnClickEvent("delete", function()
        self:deleteSelectedCharacter()
    end)
    
    self.nodes.logoutButton:addOnClickEvent("logout", function()
        self:logout()
    end)
    
    -- Événements du formulaire de création rapide
    self.nodes.quickNameInput:setOnEnter(function(text)
        self:quickCreateCharacter()
    end)
    
    self.nodes.quickCreateConfirmButton:addOnClickEvent("quick_create_confirm", function()
        self:quickCreateCharacter()
    end)
    
    self.nodes.quickCancelButton:addOnClickEvent("quick_cancel", function()
        self:hideQuickCreateForm()
    end)
    
    -- Événements du gestionnaire d'authentification
    self.authManager:onCharactersLoaded(function(characters)
        self.characters = characters
        self:updateCharacterList()
        self:updateStatusLabel("Personnages chargés")
    end)
    
    self.authManager:onCharacterCreated(function(character)
        self.isLoading = false
        self.successMessage = "Personnage créé avec succès!"
        self:updateStatusLabel()
        self:hideQuickCreateForm()
        
        -- Recharger la liste des personnages
        self:loadUserData()
    end)
    
    self.authManager:onCharacterCreationError(function(error)
        self.isLoading = false
        self.errorMessage = error
        self:updateStatusLabel()
    end)
    
    self.authManager:onCharacterDeleted(function(characterName)
        self.isLoading = false
        self.successMessage = "Personnage supprimé"
        self:updateStatusLabel()
        
        -- Recharger la liste des personnages
        self:loadUserData()
        self.selectedCharacter = nil
        self.selectedCharacterIndex = 0
    end)
    
    self.authManager:onCharacterDeleteError(function(error)
        self.isLoading = false
        self.errorMessage = error
        self:updateStatusLabel()
    end)
    
    self.authManager:onWorldJoin(function(worldInfo, characterName)
        self.isLoading = false
        self.successMessage = "Connexion au monde " .. worldInfo.name .. "..."
        self:updateStatusLabel()
        
        -- Créer le WorldServer et passer à la scène de jeu
        self:connectToWorld(worldInfo, characterName)
    end)
end

function CharacterSelectScene:loadUserData()
    local user = self.authManager:getCurrentUser()
    if user then
        self.nodes.userInfoLabel.text:set("Connecté: " .. user.email)
        
        -- Charger les personnages via l'AuthManager
        self.authManager:loadCharacters()
    else
        -- Pas d'utilisateur connecté, retourner à la connexion
        print("[CHARACTER-SELECT] Aucun utilisateur connecté")
        _G.xle.Scene.goToScene("scene-login")
    end
end

function CharacterSelectScene:updateCharacterList()
    -- Supprimer les anciens boutons de personnage
    for k in pairs(self.nodes) do
        if string.find(k, "character_") then
            self.nodes[k] = nil
        end
    end
    
    -- Afficher un message si aucun personnage
    if #self.characters == 0 then
        local centerX = self.screenWidth / 2
        local centerY = self.screenHeight / 2
        local startY = centerY - 250
        local startX = 50
        
        self.nodes.noCharacterLabel = LabelElement:new("Aucun personnage trouvé", startX, startY + 50)
    else
        self.nodes.noCharacterLabel = nil
    end
    
    -- Mettre à jour l'aperçu
    self:updateCharacterPreview()
end

function CharacterSelectScene:selectCharacter(character, index)
    self.selectedCharacter = character
    self.selectedCharacterIndex = index
    
    self.nodes.playButton.disabled = false
    self.nodes.deleteButton.disabled = false
    
    self:updateCharacterPreview()
    self:updateStatusLabel("Personnage sélectionné: " .. character.name)
    
    print("[CHARACTER-SELECT] Personnage sélectionné:", character.name)
end

function CharacterSelectScene:updateCharacterPreview()
    if self.selectedCharacter then
        local character = self.selectedCharacter
        local data = character.data and character.data or {}
        
        -- Titre de l'aperçu
        self.nodes.previewLabel.text:set("✦ " .. character.name)
        
        -- Détails du personnage
        local details = ""
        if data.clan then
            details = details .. "Clan: " .. data.clan .. "\n"
        end
        if data.level then
            details = details .. "Niveau: " .. data.level .. "\n"
        end
        if data.stats then
            details = details .. "\nStatistiques:\n"
            details = details .. "• Force: " .. (data.stats.force or 10) .. "\n"
            details = details .. "• Intelligence: " .. (data.stats.intelligence or 10) .. "\n"
            details = details .. "• Vitesse: " .. (data.stats.speed or 10) .. "\n"
            details = details .. "• Agilité: " .. (data.stats.agility or 10) .. "\n"
        end
        if data.wallet then
            details = details .. "\nWallet: " .. data.wallet .. " pièces\n"
        end
        if character.last_played then
            details = details .. "\nDernière connexion:\n" .. character.last_played
        end
        
        self.nodes.previewDetails.text:set(details)
    else
        self.nodes.previewLabel.text:set("Aperçu")
        self.nodes.previewDetails.text:set("Sélectionnez un personnage\npour voir ses détails")
    end
end

function CharacterSelectScene:openAdvancedCreation()
    -- Passer à la scène de création avancée
    _G.xle.Scene.goToScene("scene-character-creation")
end

function CharacterSelectScene:showQuickCreateForm()
    self.showQuickCreate = true
    self:updateUIVisibility()
    self.nodes.quickNameInput:focus()
end

function CharacterSelectScene:hideQuickCreateForm()
    self.showQuickCreate = false
    self.nodes.quickNameInput:setText("")
    self:updateUIVisibility()
end

function CharacterSelectScene:quickCreateCharacter()
    local name = self.nodes.quickNameInput:getText()
    
    if not self.nodes.quickNameInput:validate() or name == "" then
        self.errorMessage = "Nom invalide"
        self:updateStatusLabel()
        return
    end
    
    self.isLoading = true
    self:updateStatusLabel()
    
    -- Créer un personnage avec des stats par défaut
    local characterData = {
        name = name,
        clan = "Neutral",
        stats = {
            force = 13,
            intelligence = 13,
            speed = 13,
            agility = 13
        }
    }
    
    -- Créer le personnage via l'AuthManager
    self.authManager:createCharacter(characterData)
end

function CharacterSelectScene:playSelectedCharacter()
    if not self.selectedCharacter then
        self.errorMessage = "Aucun personnage sélectionné"
        self:updateStatusLabel()
        return
    end
    
    self.isLoading = true
    self:updateStatusLabel()
    
    -- Jouer avec le personnage sélectionné
    self.authManager:playCharacter(self.selectedCharacter.name)
end

function CharacterSelectScene:deleteSelectedCharacter()
    if not self.selectedCharacter then
        self.errorMessage = "Aucun personnage sélectionné"
        self:updateStatusLabel()
        return
    end
    
    -- Demander confirmation (simple pour l'instant)
    print("[CHARACTER-SELECT] Suppression du personnage:", self.selectedCharacter.name)
    
    self.isLoading = true
    self:updateStatusLabel()
    
    -- Supprimer le personnage
    self.authManager:deleteCharacter(self.selectedCharacter.name)
end

function CharacterSelectScene:logout()
    self.authManager:logout()
    _G.xle.Scene.goToScene("scene-login")
end

function CharacterSelectScene:connectToWorld(worldInfo, characterName)
    print("[CHARACTER-SELECT] Connexion au monde:", worldInfo.name, "IP:", worldInfo.ip, "Port:", worldInfo.port)
    
    -- S'assurer que _G.user est correctement configuré
    if not _G.user then
        _G.user = {}
    end
    
    -- Synchroniser les données utilisateur
    _G.user.email = self.authManager:getCurrentUser().email
    _G.user.token = self.authManager:getCurrentUser().token
    _G.user.characters = self.authManager:getCurrentUser().characters or {}
    _G.user.selectedCharacter = characterName
    
    -- Trouver les données du personnage sélectionné
    for _, character in ipairs(self.characters) do
        if character.name == characterName then
            _G.user.characterData = character
            break
        end
    end
    
    print("[CHARACTER-SELECT] Données utilisateur configurées:")
    print("  Email:", _G.user.email)
    print("  Token:", _G.user.token and "existe" or "nil")
    print("  Personnage sélectionné:", _G.user.selectedCharacter)
    print("  WorldServer:", _G.worldServer and "créé" or "non créé")
    
    -- Le WorldServer est déjà créé par l'AuthManager, on peut passer à la scène de jeu
    print("[CHARACTER-SELECT] Passage à la scène de jeu")
    _G.xle.Scene.goToScene("scene-play")
end

function CharacterSelectScene:updateUIVisibility()
    -- Masquer/afficher les éléments selon l'état
    local quickCreateVisible = self.showQuickCreate
    
    -- Boutons principaux (cachés pendant la création rapide)
    self.nodes.createAdvancedButton.visible = not quickCreateVisible
    self.nodes.quickCreateButton.visible = not quickCreateVisible
    self.nodes.playButton.visible = not quickCreateVisible
    self.nodes.deleteButton.visible = not quickCreateVisible
    self.nodes.logoutButton.visible = not quickCreateVisible
    
    -- Liste des personnages (cachée pendant la création rapide)
    self.nodes.characterListLabel.visible = not quickCreateVisible
    self.nodes.previewLabel.visible = not quickCreateVisible
    self.nodes.previewDetails.visible = not quickCreateVisible
    
    -- Note: Plus besoin de gérer les boutons de personnage car ils n'existent plus
    -- La sélection se fait maintenant directement via mousepressed()
    
    -- Formulaire de création rapide (visible seulement pendant la création)
    self.nodes.quickCreateLabel.visible = quickCreateVisible
    self.nodes.quickNameInput.visible = quickCreateVisible
    self.nodes.quickCreateConfirmButton.visible = quickCreateVisible
    self.nodes.quickCancelButton.visible = quickCreateVisible
    
    -- Désactiver les boutons selon l'état
    self.nodes.playButton.disabled = not self.selectedCharacter
    self.nodes.deleteButton.disabled = not self.selectedCharacter
end

function CharacterSelectScene:updateStatusLabel(message)
    local text = message or ""
    if self.isLoading then
        text = "Chargement..."
    elseif self.errorMessage ~= "" then
        text = self.errorMessage
    elseif self.successMessage ~= "" then
        text = self.successMessage
    end
    
    self.nodes.statusLabel.text:set(text)
    
    -- Effacer les messages après un délai
    if self.errorMessage ~= "" or self.successMessage ~= "" then
        love.timer.sleep(0.1)
        self.errorMessage = ""
        self.successMessage = ""
    end
end

function CharacterSelectScene:update(dt, ...)
    -- Mettre à jour l'AuthManager
    self.authManager:update(dt)
    
    -- Mettre à jour les éléments UI
    for k, node in pairs(self.nodes) do
        if node and node.update and (node.visible ~= false) then
            node:update(dt, ...)
        end
    end
end

function CharacterSelectScene:draw(...)
    -- Fond dégradé
    love.graphics.setColor(0.05, 0.05, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    
    -- Dessiner les éléments UI standard
    for k, node in pairs(self.nodes) do
        if node and node.draw and (node.visible ~= false) and not string.find(k, "character_") then
            -- Colorer selon le type d'élément
            if k == "titleLabel" then
                love.graphics.setColor(1, 0.8, 0.2, 1)
            elseif k == "subtitleLabel" then
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
            elseif k == "characterListLabel" then
                love.graphics.setColor(0.9, 0.9, 1, 1)
            elseif k == "previewLabel" then
                love.graphics.setColor(0.8, 1, 0.8, 1)
            elseif k == "previewDetails" then
                love.graphics.setColor(0.9, 0.9, 0.9, 1)
            elseif k == "helpLabel" then
                love.graphics.setColor(0.7, 0.7, 0.7, 1)
            else
                love.graphics.setColor(1, 1, 1, 1)
            end
            
            node:draw(...)
        end
    end
    
    -- Dessiner les cartes de personnage personnalisées
    if not self.showQuickCreate then
        self:drawCharacterCards()
    end
    
    -- Indicateur de chargement
    if self.isLoading then
        love.graphics.setColor(1, 1, 1, 0.8)
        local centerX = self.screenWidth / 2
        local centerY = self.screenHeight / 2
        love.graphics.circle("line", centerX, centerY, 10 + math.sin(love.timer.getTime() * 5) * 5)
    end
    
    -- Remettre la couleur par défaut
    love.graphics.setColor(1, 1, 1, 1)
end

function CharacterSelectScene:drawCharacterCards()
    local centerX = self.screenWidth / 2
    local centerY = self.screenHeight / 2
    local startY = centerY - 250
    local startX = 50
    
    for i, character in ipairs(self.characters) do
        local cardY = startY + 30 + ((i - 1) * 60)
        local cardX = startX
        local cardWidth = 350
        local cardHeight = 50
        
        -- Couleur de fond selon la sélection
        if i == self.selectedCharacterIndex then
            love.graphics.setColor(0.3, 0.6, 1, 0.3)
        else
            love.graphics.setColor(0.2, 0.2, 0.3, 0.8)
        end
        love.graphics.rectangle("fill", cardX, cardY, cardWidth, cardHeight)
        
        -- Bordure
        if i == self.selectedCharacterIndex then
            love.graphics.setColor(0.3, 0.6, 1, 1)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
        end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cardX, cardY, cardWidth, cardHeight)
        
        -- Indicateur de clan (si présent)
        if character.data and character.data.clan then
            local clanColor = self.clanColors[character.data.clan] or {1, 1, 1, 1}
            love.graphics.setColor(clanColor)
            love.graphics.rectangle("fill", cardX + 5, cardY + 5, 5, cardHeight - 10)
        end
        
        -- Nom du personnage
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(character.name, cardX + 20, cardY + 8)
        
        -- Clan (si présent)
        if character.data and character.data.clan then
            local clanColor = self.clanColors[character.data.clan] or {1, 1, 1, 1}
            love.graphics.setColor(clanColor[1], clanColor[2], clanColor[3], 0.8)
            love.graphics.print("(" .. character.data.clan .. ")", cardX + 20, cardY + 25)
        end
        
        -- Niveau (si présent)
        if character.data and character.data.level then
            love.graphics.setColor(0.8, 0.8, 0.2, 1)
            love.graphics.print("Niv. " .. character.data.level, cardX + 200, cardY + 8)
        end
        
        -- Stats totales
        if character.data and character.data.stats then
            local totalStats = (character.data.stats.force or 10) + 
                              (character.data.stats.intelligence or 10) + 
                              (character.data.stats.speed or 10) + 
                              (character.data.stats.agility or 10)
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            love.graphics.print("Stats: " .. totalStats, cardX + 200, cardY + 25)
        end
        
        -- Wallet (si présent)
        if character.data and character.data.wallet then
            love.graphics.setColor(1, 0.8, 0.2, 1)
            love.graphics.print("$" .. character.data.wallet, cardX + 290, cardY + 8)
        end
    end
end

function CharacterSelectScene:mousepressed(x, y, button, ...)
    local handled = false
    
    -- Vérifier d'abord si on clique sur une carte de personnage
    if not self.showQuickCreate and #self.characters > 0 then
        local centerX = self.screenWidth / 2
        local centerY = self.screenHeight / 2
        local startY = centerY - 250
        local startX = 50
        
        for i, character in ipairs(self.characters) do
            local cardY = startY + 30 + ((i - 1) * 60)
            local cardX = startX
            local cardWidth = 350
            local cardHeight = 50
            
            -- Vérifier si le clic est sur cette carte
            if x >= cardX and x <= cardX + cardWidth and y >= cardY and y <= cardY + cardHeight then
                self:selectCharacter(character, i)
                handled = true
                break
            end
        end
    end
    
    -- Si ce n'est pas traité, traiter les autres éléments UI
    if not handled then
        for k, node in pairs(self.nodes) do
            if node and node.mousepressed and (node.visible ~= false) then
                if node:mousepressed(x, y, button, ...) then
                    handled = true
                    break
                end
            end
        end
    end
    
    -- Si aucun élément n'a traité le clic, défocuser les champs de texte
    if not handled and _G.textInputFocused then
        _G.textInputFocused:blur()
    end
end

function CharacterSelectScene:mousereleased(x, y, button, ...)
    for k, node in pairs(self.nodes) do
        if node and node.mousereleased and (node.visible ~= false) then
            node:mousereleased(x, y, button, ...)
        end
    end
end

function CharacterSelectScene:mousemoved(x, y, ...)
    for k, node in pairs(self.nodes) do
        if node and node.mousemoved and (node.visible ~= false) then
            node:mousemoved(x, y, ...)
        end
    end
end

function CharacterSelectScene:textinput(text)
    for k, node in pairs(self.nodes) do
        if node and node.textinput and (node.visible ~= false) then
            node:textinput(text)
        end
    end
end

function CharacterSelectScene:keypressed(key)
    for k, node in pairs(self.nodes) do
        if node and node.keypressed and (node.visible ~= false) then
            if node:keypressed(key) then
                return -- Un élément a traité la touche
            end
        end
    end
    
    -- Navigation avec les flèches
    if key == "up" and self.selectedCharacterIndex > 1 then
        self:selectCharacter(self.characters[self.selectedCharacterIndex - 1], self.selectedCharacterIndex - 1)
    elseif key == "down" and self.selectedCharacterIndex < #self.characters then
        self:selectCharacter(self.characters[self.selectedCharacterIndex + 1], self.selectedCharacterIndex + 1)
    elseif key == "return" and self.selectedCharacter then
        self:playSelectedCharacter()
    elseif key == "escape" then
        if self.showQuickCreate then
            self:hideQuickCreateForm()
        else
            self:logout()
        end
    end
end

return CharacterSelectScene 
