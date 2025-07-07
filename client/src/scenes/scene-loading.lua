local LoadingScene = require(_G.libDir .. "middleclass")("LoadingScene", _G.xle.Scene)
local LabelElement = require(_G.engineDir .. "builtin.gameobjects.label")
local AuthManager = require(_G.libDir .. "auth-manager")

function LoadingScene:initialize(name, active)
    _G.xle.Scene.initialize(self, name, active)
    
    -- Gestionnaire d'authentification (instance globale)
    if not _G.authManager then
        _G.authManager = AuthManager:new()
    end
    self.authManager = _G.authManager
    
    -- État de l'interface
    self.currentStep = "connecting"
    self.statusMessage = "Connexion au serveur..."
    self.errorMessage = ""
    self.autoLoginAttempted = false
    
    -- Animation de loading
    self.loadingAnimation = 0
    self.dots = ""
    
    -- Timing
    self.timeoutTimer = 0
    self.maxTimeout = 10 -- 10 secondes de timeout
    
    -- Navigation différée pour éviter les erreurs d'initialisation
    self.pendingSceneChange = nil
    self.sceneChangeTimer = 0
    self.sceneChangeDelay = 1.0 -- Délai en secondes avant changement de scène
    
    -- Auto-login différé
    self.autoLoginTimer = 0
    self.autoLoginDelay = 0
    
    print("[LOADING] Scène de chargement initialisée")
end

function LoadingScene:init()
    _G.xle.Scene.init(self)
    love.window.setTitle("Forgotten Kingdom - Chargement")
    
    -- Récupérer les dimensions écran
    self.screenWidth, self.screenHeight = love.graphics.getDimensions()
    
    -- Calculer les positions centrées
    local centerX = self.screenWidth / 2
    local centerY = self.screenHeight / 2
    
    -- Initialiser les éléments UI
    self.nodes = {
        -- Titre du jeu
        titleLabel = LabelElement:new("FORGOTTEN KINGDOM", centerX - 120, centerY - 100),
        
        -- Message de statut principal
        statusLabel = LabelElement:new("Initialisation...", centerX - 100, centerY - 20),
        
        -- Message de statut détaillé
        detailLabel = LabelElement:new("", centerX - 150, centerY + 20),
        
        -- Message d'erreur (si nécessaire)
        errorLabel = LabelElement:new("", centerX - 200, centerY + 60),
        
        -- Instructions
        instructionLabel = LabelElement:new("", centerX - 100, centerY + 100)
    }
    
    -- Configuration des événements
    self:setupEvents()
    
    -- Démarrer la séquence de connexion
    self:startConnectionSequence()
end

function LoadingScene:setupEvents()
    -- Événements du gestionnaire d'authentification
    self.authManager:onConnected(function()
        print("[LOADING] Connecté au master server")
        self:setStatus("connected", "Connecté au serveur")
        
        -- Tenter l'auto-login après connexion réussie
        self:attemptAutoLogin()
    end)
    
    self.authManager:onDisconnected(function(error)
        print("[LOADING] Déconnecté du master server:", error or "")
        self:setStatus("error", "Erreur de connexion", error or "Impossible de se connecter au serveur")
    end)
    
    self.authManager:onAutoLoginAttempt(function(email)
        print("[LOADING] Tentative de connexion automatique pour:", email)
        self:setStatus("auto_login", "Connexion automatique", "Connexion avec le compte " .. email)
    end)
    
    self.authManager:onLoginSuccess(function(user)
        print("[LOADING] Connexion automatique réussie pour:", user.email)
        self:setStatus("success", "Connexion réussie", "Bienvenue " .. user.email)
        
        -- Programmer le changement de scène
        self:scheduleSceneChange("scene-character-select")
    end)
    
    self.authManager:onLoginError(function(error)
        print("[LOADING] Échec connexion automatique:", error)
        if error:find("token") or error:find("Session") then
            -- Problème de token, aller à la connexion manuelle
            self:setStatus("token_expired", "Session expirée", "Redirection vers la connexion...")
            self:scheduleSceneChange("scene-login", 2.0)
        else
            -- Autre erreur
            self:setStatus("error", "Erreur de connexion", error)
        end
    end)
    
    self.authManager:onTokenLoadError(function(error)
        print("[LOADING] Pas de token sauvegardé ou token invalide:", error)
        -- Aller directement à la scène de connexion
        self:setStatus("no_token", "Première connexion", "Redirection vers la connexion...")
        self:scheduleSceneChange("scene-login")
    end)
end

function LoadingScene:startConnectionSequence()
    print("[LOADING] Début de la séquence de connexion")
    self:setStatus("connecting", "Connexion au serveur")
    
    -- Connexion au master server
    self.authManager:connectToMasterServer()
end

function LoadingScene:attemptAutoLogin()
    if self.autoLoginAttempted then
        return
    end
    
    self.autoLoginAttempted = true
    
    print("[LOADING] Tentative d'auto-login")
    self:setStatus("checking_token", "Vérification du token sauvegardé")
    
    -- Programmer la tentative de connexion automatique avec un petit délai pour l'UX
    self.autoLoginDelay = 0.5
    self.autoLoginTimer = 0
end

function LoadingScene:setStatus(step, message, detail)
    self.currentStep = step
    self.statusMessage = message
    
    if detail then
        self.nodes.detailLabel.text:set(detail)
    end
    
    -- Mettre à jour les couleurs selon l'état
    if step == "error" or step == "token_expired" then
        self.errorMessage = detail or message
        self.nodes.errorLabel.text:set(self.errorMessage)
    else
        self.errorMessage = ""
        self.nodes.errorLabel.text:set("")
    end
    
    -- Instructions selon l'état
    if step == "error" then
        self.nodes.instructionLabel.text:set("Appuyez sur Entrée pour aller à la connexion manuelle")
    elseif step == "no_token" or step == "token_expired" then
        self.nodes.instructionLabel.text:set("Redirection automatique...")
    else
        self.nodes.instructionLabel.text:set("")
    end
    
    print("[LOADING] Statut:", step, "-", message)
end

function LoadingScene:scheduleSceneChange(sceneName, delay)
    self.pendingSceneChange = sceneName
    self.sceneChangeTimer = 0
    self.sceneChangeDelay = delay or 1.0
    print("[LOADING] Changement de scène programmé vers:", sceneName, "dans", self.sceneChangeDelay, "secondes")
end

function LoadingScene:update(dt, ...)
    -- Mettre à jour l'AuthManager
    self.authManager:update(dt)
    
    -- Gérer l'auto-login différé
    if self.autoLoginDelay > 0 then
        self.autoLoginTimer = self.autoLoginTimer + dt
        if self.autoLoginTimer >= self.autoLoginDelay then
            -- Tenter la connexion automatique
            local success = self.authManager:attemptAutoLogin()
            if not success then
                print("[LOADING] Pas de token valide, redirection vers login")
            end
            self.autoLoginDelay = 0 -- Réinitialiser pour ne pas refaire
        end
    end
    
    -- Gérer les changements de scène différés
    if self.pendingSceneChange then
        self.sceneChangeTimer = self.sceneChangeTimer + dt
        if self.sceneChangeTimer >= self.sceneChangeDelay then
            print("[LOADING] Exécution du changement de scène vers:", self.pendingSceneChange)
            
            -- Vérifier que xleInstance est disponible avant de changer de scène
            if _G.xleInstance and _G.xle and _G.xle.Scene then
                _G.xle.Scene.goToScene(self.pendingSceneChange)
                self.pendingSceneChange = nil
            else
                print("[LOADING] XLE pas encore prêt, on attend encore...")
                -- Réessayer dans 0.1 seconde
                self.sceneChangeTimer = self.sceneChangeDelay - 0.1
            end
        end
    end
    
    -- Animation de loading
    self.loadingAnimation = self.loadingAnimation + dt * 3
    local dotCount = math.floor(self.loadingAnimation) % 4
    self.dots = string.rep(".", dotCount)
    
    -- Mettre à jour le message avec animation
    if self.currentStep ~= "error" and self.currentStep ~= "success" then
        self.nodes.statusLabel.text:set(self.statusMessage .. self.dots)
    else
        self.nodes.statusLabel.text:set(self.statusMessage)
    end
    
    -- Timeout de sécurité
    self.timeoutTimer = self.timeoutTimer + dt
    if self.timeoutTimer > self.maxTimeout and self.currentStep ~= "success" and self.currentStep ~= "error" then
        self:setStatus("error", "Timeout de connexion", "Le serveur met trop de temps à répondre")
    end
    
    -- Mettre à jour les éléments UI
    for k, node in pairs(self.nodes) do
        if node.update then
            node:update(dt, ...)
        end
    end
end

function LoadingScene:draw(...)
    -- Fond dégradé sombre
    love.graphics.setColor(0.05, 0.05, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    
    -- Dessiner les éléments UI
    for k, node in pairs(self.nodes) do
        if node.draw then
            -- Colorer selon le type d'élément
            if k == "titleLabel" then
                love.graphics.setColor(1, 0.8, 0.2, 1) -- Doré
            elseif k == "statusLabel" then
                love.graphics.setColor(0.8, 0.8, 1, 1) -- Bleu clair
            elseif k == "detailLabel" then
                love.graphics.setColor(0.6, 0.6, 0.8, 1) -- Gris bleu
            elseif k == "errorLabel" then
                love.graphics.setColor(1, 0.3, 0.3, 1) -- Rouge
            elseif k == "instructionLabel" then
                love.graphics.setColor(0.8, 0.8, 0.2, 1) -- Jaune
            else
                love.graphics.setColor(1, 1, 1, 1) -- Blanc par défaut
            end
            
            node:draw(...)
        end
    end
    
    -- Cercle de loading animé
    if self.currentStep ~= "error" and self.currentStep ~= "success" then
        love.graphics.setColor(0.4, 0.6, 1, 0.8)
        local centerX = self.screenWidth / 2
        local centerY = self.screenHeight / 2 + 140
        local radius = 15 + math.sin(self.loadingAnimation * 2) * 3
        love.graphics.circle("line", centerX, centerY, radius)
        
        -- Points rotatifs
        love.graphics.setColor(1, 1, 1, 0.9)
        for i = 1, 8 do
            local angle = (self.loadingAnimation + i * 0.5) * 2
            local x = centerX + math.cos(angle) * (radius + 5)
            local y = centerY + math.sin(angle) * (radius + 5)
            love.graphics.circle("fill", x, y, 2)
        end
    end
    
    -- Remettre la couleur par défaut
    love.graphics.setColor(1, 1, 1, 1)
end

function LoadingScene:keypressed(key)
    -- Échapper ou Entrée pour aller à la connexion manuelle en cas d'erreur
    if (key == "escape" or key == "return") and self.currentStep == "error" then
        self:scheduleSceneChange("scene-login", 0.1)
    elseif key == "escape" then
        love.event.quit()
    end
end

function LoadingScene:mousepressed(x, y, button, ...)
    -- Clic pour aller à la connexion manuelle en cas d'erreur
    if self.currentStep == "error" then
        self:scheduleSceneChange("scene-login", 0.1)
    end
end

return LoadingScene 
