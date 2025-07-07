local LoginScene = require(_G.libDir .. "middleclass")("LoginScene", _G.xle.Scene)
local TextInputElement = require(_G.engineDir .. "builtin.gameobjects.text-input")
local ButtonElement = require(_G.engineDir .. "builtin.gameobjects.button")
local LabelElement = require(_G.engineDir .. "builtin.gameobjects.label")
local FormValidator = require(_G.libDir .. "form-validator")
local AuthManager = require(_G.libDir .. "auth-manager")

function LoginScene:initialize(name, active)
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
    
    -- Réponse adaptative
    self.screenWidth = 0
    self.screenHeight = 0
    
    print("[LOGIN] Scène de connexion initialisée")
end

function LoginScene:init()
    _G.xle.Scene.init(self)
    love.window.setTitle("Forgotten Kingdom - Connexion")
    
    -- Récupérer les dimensions écran
    self.screenWidth, self.screenHeight = love.graphics.getDimensions()
    
    -- Calculer les positions centrées
    local centerX = self.screenWidth / 2
    local centerY = self.screenHeight / 2
    local formWidth = 300
    local startY = centerY - 150
    
    -- Initialiser les éléments UI
    self.nodes = {
        -- Titre
        titleLabel = LabelElement:new("FORGOTTEN KINGDOM", centerX - 120, startY - 60),
        subtitleLabel = LabelElement:new("Connexion", centerX - 40, startY - 30),
        
        -- Champs de saisie
        emailInput = TextInputElement:new(centerX - formWidth/2, startY, formWidth, "Adresse email"),
        passwordInput = TextInputElement:new(centerX - formWidth/2, startY + 50, formWidth, "Mot de passe", true),
        
        -- Boutons
        loginButton = ButtonElement:new("Se connecter", centerX - 50, startY + 100),
        registerButton = ButtonElement:new("Créer un compte", centerX - 65, startY + 140),
        clearTokenButton = ButtonElement:new("Nouvelle session", centerX - 60, startY + 180),
        
        -- Labels d'état
        statusLabel = LabelElement:new("", centerX - 150, startY + 220),
        connectionLabel = LabelElement:new("Connexion au serveur...", centerX - 80, startY + 250)
    }
    
    -- Configuration des validateurs
    self.nodes.emailInput:setValidator(FormValidator.createEmailValidator())
    self.nodes.passwordInput:setValidator(FormValidator.createPasswordValidator())
    
    -- Configuration des événements
    self:setupEvents()
    
    -- Connexion automatique au master server
    self:connectToServer()
end

function LoginScene:setupEvents()
    -- Événements des champs de saisie
    self.nodes.emailInput:setOnEnter(function(text)
        if self.nodes.passwordInput:getText() ~= "" then
            self:attemptLogin()
        else
            self.nodes.passwordInput:focus()
        end
    end)
    
    self.nodes.passwordInput:setOnEnter(function(text)
        if self.nodes.emailInput:getText() ~= "" then
            self:attemptLogin()
        end
    end)
    
    -- Événements des boutons
    self.nodes.loginButton:addOnClickEvent("login", function()
        self:attemptLogin()
    end)
    
    self.nodes.registerButton:addOnClickEvent("register", function()
        self:goToRegister()
    end)
    
    self.nodes.clearTokenButton:addOnClickEvent("clear_token", function()
        self:clearSavedToken()
    end)
    
    -- Événements du gestionnaire d'authentification
    self.authManager:onConnected(function()
        self.nodes.connectionLabel.text:set("Connecté au serveur")
        self.nodes.loginButton.disabled = false
        self.nodes.registerButton.disabled = false
    end)
    
    self.authManager:onDisconnected(function(error)
        self.nodes.connectionLabel.text:set("Déconnecté: " .. (error or ""))
        self.nodes.loginButton.disabled = true
        self.nodes.registerButton.disabled = true
    end)
    
    self.authManager:onLoginSuccess(function(user)
        self.isLoading = false
        self.successMessage = "Connexion réussie! Bienvenue " .. user.email
        self:updateStatusLabel()
        
        -- Passer à la scène de sélection de personnage
        love.timer.sleep(1)
        _G.xle.Scene.goToScene("scene-character-select")
    end)
    
    self.authManager:onLoginError(function(error)
        self.isLoading = false
        self.errorMessage = error
        self:updateStatusLabel()
        
        -- Réactiver les boutons
        self.nodes.loginButton.disabled = false
        self.nodes.registerButton.disabled = false
    end)
end

function LoginScene:connectToServer()
    print("[LOGIN] Connexion au master server")
    self.nodes.connectionLabel.text:set("Connexion au serveur...")
    self.nodes.loginButton.disabled = true
    self.nodes.registerButton.disabled = true
    
    self.authManager:connectToMasterServer()
end

function LoginScene:attemptLogin()
    -- Nettoyer les messages précédents
    self.errorMessage = ""
    self.successMessage = ""
    
    -- Valider les champs
    local emailValid = self.nodes.emailInput:validate()
    local passwordValid = self.nodes.passwordInput:validate()
    
    if not emailValid or not passwordValid then
        self.errorMessage = "Veuillez corriger les erreurs dans le formulaire"
        self:updateStatusLabel()
        return
    end
    
    -- Récupérer les valeurs
    local email = FormValidator.sanitizeInput(self.nodes.emailInput:getText())
    local password = self.nodes.passwordInput:getText()
    
    print("[LOGIN] Tentative de connexion pour:", email)
    
    -- Démarrer le loading
    self.isLoading = true
    self.nodes.loginButton.disabled = true
    self.nodes.registerButton.disabled = true
    
    -- Tenter la connexion
    local success = self.authManager:login(email, password)
    
    if not success then
        self.isLoading = false
        self.errorMessage = self.authManager:getLastError() or "Erreur inconnue"
        self:updateStatusLabel()
        self.nodes.loginButton.disabled = false
        self.nodes.registerButton.disabled = false
    end
end

function LoginScene:goToRegister()
    print("[LOGIN] Redirection vers l'inscription")
    _G.xle.Scene.goToScene("scene-register")
end

function LoginScene:clearSavedToken()
    print("[LOGIN] Suppression du token sauvegardé")
    self.authManager:clearSavedToken()
    self.successMessage = "Token sauvegardé supprimé. Vous pourrez vous connecter avec un autre compte."
    self:updateStatusLabel()
    
    -- Effacer le message après quelques secondes
    love.timer.sleep(2)
    self.successMessage = ""
    self:updateStatusLabel()
end

function LoginScene:updateStatusLabel()
    local text = ""
    if self.isLoading then
        text = "Connexion en cours..."
    elseif self.errorMessage ~= "" then
        text = self.errorMessage
    elseif self.successMessage ~= "" then
        text = self.successMessage
    end
    
    self.nodes.statusLabel.text:set(text)
end

function LoginScene:update(dt, ...)
    -- Mettre à jour l'AuthManager
    self.authManager:update(dt)
    
    -- Mettre à jour les éléments UI
    for k, node in pairs(self.nodes) do
        if node.update then
            node:update(dt, ...)
        end
    end
    
    -- Mettre à jour le label de statut
    self:updateStatusLabel()
end

function LoginScene:draw(...)
    -- Fond dégradé
    love.graphics.setColor(0.1, 0.1, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    
    -- Dessiner les éléments UI
    for k, node in pairs(self.nodes) do
        if node.draw then
            -- Colorer le titre
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
            elseif k == "connectionLabel" then
                love.graphics.setColor(0.6, 0.6, 0.6, 1)
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

function LoginScene:mousepressed(x, y, button, ...)
    local handled = false
    for k, node in pairs(self.nodes) do
        if node.mousepressed then
            if node:mousepressed(x, y, button, ...) then
                handled = true
            end
        end
    end
    
    -- Si aucun élément n'a traité le clic, défocuser les champs de texte
    if not handled and _G.textInputFocused then
        _G.textInputFocused:blur()
    end
end

function LoginScene:mousereleased(x, y, button, ...)
    for k, node in pairs(self.nodes) do
        if node.mousereleased then
            node:mousereleased(x, y, button, ...)
        end
    end
end

function LoginScene:textinput(text)
    for k, node in pairs(self.nodes) do
        if node.textinput then
            node:textinput(text)
        end
    end
end

function LoginScene:keypressed(key)
    for k, node in pairs(self.nodes) do
        if node.keypressed then
            node:keypressed(key)
        end
    end
    
    -- Échapper pour quitter
    if key == "escape" then
        love.event.quit()
    end
end

return LoginScene 
