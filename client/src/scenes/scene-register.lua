local RegisterScene = require(_G.libDir .. "middleclass")("RegisterScene", _G.xle.Scene)
local TextInputElement = require(_G.engineDir .. "builtin.gameobjects.text-input")
local ButtonElement = require(_G.engineDir .. "builtin.gameobjects.button")
local LabelElement = require(_G.engineDir .. "builtin.gameobjects.label")
local FormValidator = require(_G.libDir .. "form-validator")
local AuthManager = require(_G.libDir .. "auth-manager")

function RegisterScene:initialize(name, active)
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
    
    print("[REGISTER] Scène d'inscription initialisée")
end

function RegisterScene:init()
    _G.xle.Scene.init(self)
    love.window.setTitle("Forgotten Kingdom - Inscription")
    
    -- Récupérer les dimensions écran
    self.screenWidth, self.screenHeight = love.graphics.getDimensions()
    
    -- Calculer les positions centrées
    local centerX = self.screenWidth / 2
    local centerY = self.screenHeight / 2
    local formWidth = 300
    local startY = centerY - 180
    
    -- Initialiser les éléments UI
    self.nodes = {
        -- Titre
        titleLabel = LabelElement:new("FORGOTTEN KINGDOM", centerX - 120, startY - 60),
        subtitleLabel = LabelElement:new("Créer un compte", centerX - 65, startY - 30),
        
        -- Champs de saisie
        emailInput = TextInputElement:new(centerX - formWidth/2, startY, formWidth, "Adresse email"),
        usernameInput = TextInputElement:new(centerX - formWidth/2, startY + 50, formWidth, "Nom d'utilisateur"),
        passwordInput = TextInputElement:new(centerX - formWidth/2, startY + 100, formWidth, "Mot de passe", true),
        confirmPasswordInput = TextInputElement:new(centerX - formWidth/2, startY + 150, formWidth, "Confirmer le mot de passe", true),
        
        -- Boutons
        registerButton = ButtonElement:new("S'inscrire", centerX - 40, startY + 200),
        backButton = ButtonElement:new("Retour", centerX - 30, startY + 240),
        
        -- Labels d'état
        statusLabel = LabelElement:new("", centerX - 150, startY + 280),
        connectionLabel = LabelElement:new("Connexion au serveur...", centerX - 80, startY + 310)
    }
    
    -- Configuration des validateurs
    self.nodes.emailInput:setValidator(FormValidator.createEmailValidator())
    self.nodes.usernameInput:setValidator(FormValidator.createUsernameValidator())
    self.nodes.passwordInput:setValidator(FormValidator.createPasswordValidator())
    self.nodes.confirmPasswordInput:setValidator(
        FormValidator.createPasswordConfirmValidator(self.nodes.passwordInput)
    )
    
    -- Configuration des événements
    self:setupEvents()
    
    -- Connexion automatique au master server
    self:connectToServer()
end

function RegisterScene:setupEvents()
    -- Événements des champs de saisie - Navigation avec Enter
    self.nodes.emailInput:setOnEnter(function(text)
        self.nodes.usernameInput:focus()
    end)
    
    self.nodes.usernameInput:setOnEnter(function(text)
        self.nodes.passwordInput:focus()
    end)
    
    self.nodes.passwordInput:setOnEnter(function(text)
        self.nodes.confirmPasswordInput:focus()
    end)
    
    self.nodes.confirmPasswordInput:setOnEnter(function(text)
        self:attemptRegister()
    end)
    
    -- Revalidation du champ de confirmation quand le mot de passe change
    self.nodes.passwordInput:setOnChange(function(text)
        if self.nodes.confirmPasswordInput:getText() ~= "" then
            self.nodes.confirmPasswordInput:validate()
        end
    end)
    
    -- Événements des boutons
    self.nodes.registerButton:addOnClickEvent("register", function()
        self:attemptRegister()
    end)
    
    self.nodes.backButton:addOnClickEvent("back", function()
        self:goToLogin()
    end)
    
    -- Événements du gestionnaire d'authentification
    self.authManager:onConnected(function()
        self.nodes.connectionLabel.text:set("Connecté au serveur")
        self.nodes.registerButton.disabled = false
    end)
    
    self.authManager:onDisconnected(function(error)
        self.nodes.connectionLabel.text:set("Déconnecté: " .. (error or ""))
        self.nodes.registerButton.disabled = true
    end)
    
    self.authManager:onRegisterSuccess(function()
        self.isLoading = false
        self.successMessage = "Inscription réussie! Vous pouvez maintenant vous connecter."
        self:updateStatusLabel()
        
        -- Rediriger vers la connexion après 2 secondes
        love.timer.sleep(2)
        self:goToLogin()
    end)
    
    self.authManager:onRegisterError(function(error)
        self.isLoading = false
        self.errorMessage = error
        self:updateStatusLabel()
        
        -- Réactiver les boutons
        self.nodes.registerButton.disabled = false
    end)
end

function RegisterScene:connectToServer()
    print("[REGISTER] Connexion au master server")
    self.nodes.connectionLabel.text:set("Connexion au serveur...")
    self.nodes.registerButton.disabled = true
    
    self.authManager:connectToMasterServer()
end

function RegisterScene:attemptRegister()
    -- Nettoyer les messages précédents
    self.errorMessage = ""
    self.successMessage = ""
    
    -- Valider tous les champs
    local emailValid = self.nodes.emailInput:validate()
    local usernameValid = self.nodes.usernameInput:validate()
    local passwordValid = self.nodes.passwordInput:validate()
    local confirmPasswordValid = self.nodes.confirmPasswordInput:validate()
    
    if not emailValid or not usernameValid or not passwordValid or not confirmPasswordValid then
        self.errorMessage = "Veuillez corriger les erreurs dans le formulaire"
        self:updateStatusLabel()
        return
    end
    
    -- Récupérer les valeurs
    local email = FormValidator.sanitizeInput(self.nodes.emailInput:getText())
    local username = FormValidator.sanitizeInput(self.nodes.usernameInput:getText())
    local password = self.nodes.passwordInput:getText()
    
    print("[REGISTER] Tentative d'inscription pour:", email)
    
    -- Démarrer le loading
    self.isLoading = true
    self.nodes.registerButton.disabled = true
    
    -- Tenter l'inscription
    local success = self.authManager:register(email, password, username)
    
    if not success then
        self.isLoading = false
        self.errorMessage = self.authManager:getLastError() or "Erreur inconnue"
        self:updateStatusLabel()
        self.nodes.registerButton.disabled = false
    end
end

function RegisterScene:goToLogin()
    print("[REGISTER] Retour à la connexion")
    _G.xle.Scene.goToScene("scene-login")
end

function RegisterScene:updateStatusLabel()
    local text = ""
    if self.isLoading then
        text = "Inscription en cours..."
    elseif self.errorMessage ~= "" then
        text = self.errorMessage
    elseif self.successMessage ~= "" then
        text = self.successMessage
    end
    
    self.nodes.statusLabel.text:set(text)
end

function RegisterScene:update(dt, ...)
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

function RegisterScene:draw(...)
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
        love.graphics.circle("line", centerX, centerY + 80, 10 + math.sin(love.timer.getTime() * 5) * 5)
    end
    
    -- Aide pour les exigences du mot de passe
    if self.nodes.passwordInput.focused then
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print("Le mot de passe doit contenir:", 10, self.screenHeight - 80)
        love.graphics.print("• Au moins 6 caractères", 10, self.screenHeight - 60)
        love.graphics.print("• Au moins une lettre", 10, self.screenHeight - 40)
        love.graphics.print("• Au moins un chiffre", 10, self.screenHeight - 20)
    end
    
    -- Remettre la couleur par défaut
    love.graphics.setColor(1, 1, 1, 1)
end

function RegisterScene:mousepressed(x, y, button, ...)
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

function RegisterScene:mousereleased(x, y, button, ...)
    for k, node in pairs(self.nodes) do
        if node.mousereleased then
            node:mousereleased(x, y, button, ...)
        end
    end
end

function RegisterScene:textinput(text)
    for k, node in pairs(self.nodes) do
        if node.textinput then
            node:textinput(text)
        end
    end
end

function RegisterScene:keypressed(key)
    for k, node in pairs(self.nodes) do
        if node.keypressed then
            node:keypressed(key)
        end
    end
    
    -- Échapper pour retourner à la connexion
    if key == "escape" then
        self:goToLogin()
    end
end

return RegisterScene 
