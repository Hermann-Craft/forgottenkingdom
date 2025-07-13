local AuthManager = require(_G.libDir .. "middleclass")("AuthManager")
local Serializer = require(_G.libDir .. "serializer")

function AuthManager:initialize()
    self.isConnected = false
    self.isAuthenticated = false
    self.currentUser = {
        email = nil,
        token = nil,
        characters = {}
    }
    
    -- Callbacks d'événements
    self.callbacks = {
        onConnected = nil,
        onDisconnected = nil,
        onLoginSuccess = nil,
        onLoginError = nil,
        onRegisterSuccess = nil,
        onRegisterError = nil,
        onCharactersLoaded = nil,
        onWorldJoin = nil,
        onTokenLoadSuccess = nil,
        onTokenLoadError = nil,
        onAutoLoginAttempt = nil
    }
    
    -- État de loading
    self.isLoading = false
    self.lastError = nil
    
    -- Configuration de la persistance
    self.tokenFilePath = "user_token.dat"
    
    print("[AUTH] Gestionnaire d'authentification initialisé")
end

-- === NOUVELLES MÉTHODES POUR LA PERSISTANCE ===

-- Sauvegarder le token dans un fichier local
function AuthManager:saveTokenToFile()
    if not self.currentUser.token or not self.currentUser.email then
        print("[AUTH] Aucun token à sauvegarder")
        return false
    end
    
    local tokenData = {
        email = self.currentUser.email,
        token = self.currentUser.token,
        savedAt = os.time()
    }
    
    -- Sérialiser les données
    local serializedData = Serializer.serialize(tokenData)
    
    -- Écrire dans le fichier
    local success, errorMsg = pcall(function()
        love.filesystem.write(self.tokenFilePath, serializedData)
    end)
    
    if success then
        print("[AUTH] Token sauvegardé avec succès")
        return true
    else
        print("[AUTH] Erreur sauvegarde token:", errorMsg)
        return false
    end
end

-- Charger le token depuis un fichier local
function AuthManager:loadTokenFromFile()
    if not love.filesystem.getInfo(self.tokenFilePath) then
        print("[AUTH] Aucun token sauvegardé trouvé")
        return nil
    end
    
    local success, data = pcall(function()
        local fileContent = love.filesystem.read(self.tokenFilePath)
        return Serializer.deserialize(fileContent)
    end)
    
    if not success or not data then
        print("[AUTH] Erreur lecture token sauvegardé")
        return nil
    end
    
    -- Vérifier la validité des données
    if not data.email or not data.token or not data.savedAt then
        print("[AUTH] Token sauvegardé corrompu")
        return nil
    end
    
    -- Vérifier l'âge du token (expire après 7 jours)
    local maxAge = 7 * 24 * 3600 -- 7 jours en secondes
    if os.time() - data.savedAt > maxAge then
        print("[AUTH] Token sauvegardé expiré")
        self:clearSavedToken()
        return nil
    end
    
    print("[AUTH] Token sauvegardé chargé:", data.email)
    return data
end

-- Supprimer le token sauvegardé
function AuthManager:clearSavedToken()
    local success = pcall(function()
        love.filesystem.remove(self.tokenFilePath)
    end)
    
    if success then
        print("[AUTH] Token sauvegardé supprimé")
    end
end

-- Tentative de connexion automatique avec token sauvegardé
function AuthManager:attemptAutoLogin()
    if not self.isConnected or not _G.masterServer then
        print("[AUTH] Pas de connexion serveur pour l'auto-login")
        if self.callbacks.onTokenLoadError then
            self.callbacks.onTokenLoadError("Non connecté au serveur")
        end
        return false
    end
    
    -- Charger le token depuis le fichier
    local tokenData = self:loadTokenFromFile()
    if not tokenData then
        if self.callbacks.onTokenLoadError then
            self.callbacks.onTokenLoadError("Aucun token sauvegardé valide")
        end
        return false
    end
    
    print("[AUTH] Tentative de connexion automatique pour:", tokenData.email)
    self.isLoading = true
    
    if self.callbacks.onAutoLoginAttempt then
        self.callbacks.onAutoLoginAttempt(tokenData.email)
    end
    
    -- Envoyer la demande de connexion par token
    _G.masterServer:send(_G.bitser.dumps({
        id = "connect_with_token",
        data = {
            email = tokenData.email,
            token = tokenData.token
        }
    }))
    
    return true
end

-- Connexion par token après validation côté serveur
function AuthManager:loginWithToken(email, token)
    if not self.isConnected or not _G.masterServer then
        self.lastError = "Non connecté au serveur"
        if self.callbacks.onLoginError then
            self.callbacks.onLoginError(self.lastError)
        end
        return false
    end
    
    print("[AUTH] Connexion par token pour:", email)
    self.isLoading = true
    
    _G.masterServer:send(_G.bitser.dumps({
        id = "connect_with_token",
        data = {
            email = email,
            token = token
        }
    }))
    
    return true
end

function AuthManager:connectToMasterServer(host, port)
    host = host or "192.168.1.58"
    port = port or 8080
    
    if _G.masterServer then
        self:disconnect()
    end
    
    print("[AUTH] Connexion au master server", host .. ":" .. port)
    
    -- Créer l'instance globale du master server
    _G.masterServer = require(_G.libDir .. "master_client"):new()
    _G.masterServer.handshake = "00000"
    
    -- Configuration des callbacks
    _G.masterServer.callbacks.recv = function(data)
        self:handleServerMessage(data)
    end
    
    -- Tentative de connexion
    local success, error = _G.masterServer:connect(host, port)
    
    if success then
        print("[AUTH] Connexion au master server réussie")
        self.isConnected = true
        
        if self.callbacks.onConnected then
            self.callbacks.onConnected()
        end
    else
        print("[AUTH] Erreur de connexion:", error)
        self.lastError = "Impossible de se connecter au serveur"
        if self.callbacks.onDisconnected then
            self.callbacks.onDisconnected(self.lastError)
        end
    end
    
    return success, error
end

function AuthManager:disconnect()
    if _G.masterServer then
        print("[AUTH] Déconnexion du master server")
        _G.masterServer:disconnect()
        _G.masterServer = nil
    end
    
    self.isConnected = false
    self.isAuthenticated = false
    self.currentUser = {
        email = nil,
        token = nil,
        characters = {}
    }
    
    if self.callbacks.onDisconnected then
        self.callbacks.onDisconnected()
    end
end

function AuthManager:handleServerMessage(data)
    local packet = _G.bitser.loads(data)
    print("[AUTH] Message reçu du serveur:", packet.id)
    
    if packet.id == "request_identity" then
        print("[AUTH] Serveur demande l'identité")
        -- Le serveur est prêt à recevoir des demandes d'auth
        
    elseif packet.id == "connection" then
        self:handleLoginResponse(packet)
        
    elseif packet.id == "register_user" then
        self:handleRegisterResponse(packet)
        
    elseif packet.id == "list_character" then
        self:handleCharacterList(packet)
        
    elseif packet.id == "play" then
        self:handleWorldJoin(packet)
        
    elseif packet.id == "create_character" then
        self:handleCharacterCreation(packet)
        
    elseif packet.id == "delete_character" then
        self:handleCharacterDeletion(packet)
        
    elseif packet.id == "logout" then
        print("[AUTH] Déconnexion confirmée par le serveur")
        
    else
        print("[AUTH] Message non géré:", packet.id)
    end
end

function AuthManager:login(email, password)
    if not self.isConnected or not _G.masterServer then
        self.lastError = "Non connecté au serveur"
        if self.callbacks.onLoginError then
            self.callbacks.onLoginError(self.lastError)
        end
        return false
    end
    
    print("[AUTH] Tentative de connexion pour:", email)
    self.isLoading = true
    
    _G.masterServer:send(_G.bitser.dumps({
        id = "connect_with_password",
        data = {
            email = email,
            password = password
        }
    }))
    
    return true
end

function AuthManager:register(email, password, username)
    if not self.isConnected or not _G.masterServer then
        self.lastError = "Non connecté au serveur"
        if self.callbacks.onRegisterError then
            self.callbacks.onRegisterError(self.lastError)
        end
        return false
    end
    
    print("[AUTH] Tentative d'inscription pour:", email)
    self.isLoading = true
    
    _G.masterServer:send(_G.bitser.dumps({
        id = "register_user",
        data = {
            email = email,
            password = password,
            username = username or email
        }
    }))
    
    return true
end

function AuthManager:handleLoginResponse(packet)
    self.isLoading = false
    
    self:log("🔍 RECEPTION TOKEN - Debut handleLoginResponse")
    self:log("packet.data.type: " .. (packet.data.type or "nil"))
    
    if packet.data.type == "success" then
        self:log("✅ Connexion réussie")
        
        -- Debug payload structure
        if packet.data.payload then
            self:log("📦 Payload reçu:")
            self:log("  email: " .. (packet.data.payload.email or "nil"))
            self:log("  token: " .. (packet.data.payload.token and "existe" or "nil"))
            if packet.data.payload.token then
                self:log("  token longueur: " .. #packet.data.payload.token)
                self:log("  token début: " .. string.sub(packet.data.payload.token, 1, 30) .. "...")
            end
            self:log("  username: " .. (packet.data.payload.username or "nil"))
        else
            self:log("❌ Aucun payload dans la réponse")
        end
        
        self.isAuthenticated = true
        self.currentUser.email = packet.data.payload.email
        self.currentUser.token = packet.data.payload.token
        
        self:log("🔄 Token stocké dans currentUser:")
        self:log("  longueur: " .. (self.currentUser.token and #self.currentUser.token or 0))
        self:log("  début: " .. (self.currentUser.token and string.sub(self.currentUser.token, 1, 30) .. "..." or "nil"))
        
        -- Synchroniser les données globales
        self:syncGlobalUser()
        
        self:log("📡 Après syncGlobalUser - vérification _G.user:")
        if _G.user then
            self:log("  _G.user.token longueur: " .. (_G.user.token and #_G.user.token or 0))
            self:log("  _G.user.token début: " .. (_G.user.token and string.sub(_G.user.token, 1, 30) .. "..." or "nil"))
        else
            self:log("  ❌ _G.user n'existe pas")
        end
        
        -- Sauvegarder le token pour les prochaines connexions
        self:saveTokenToFile()
        
        if self.callbacks.onLoginSuccess then
            self.callbacks.onLoginSuccess(self.currentUser)
        end
        
        -- Charger automatiquement la liste des personnages
        self:loadCharacters()
        
    else
        local error = packet.data.payload or "Erreur de connexion inconnue"
        self:log("❌ Erreur de connexion: " .. error)
        self.lastError = self:translateError(error)
        
        -- Si c'est une erreur de token, supprimer le token sauvegardé
        if error == "invalid_token" or error == "token_expired" then
            self:clearSavedToken()
        end
        
        if self.callbacks.onLoginError then
            self.callbacks.onLoginError(self.lastError)
        end
    end
end

function AuthManager:handleRegisterResponse(packet)
    self.isLoading = false
    
    if packet.data.type == "success" then
        print("[AUTH] Inscription réussie")
        
        if self.callbacks.onRegisterSuccess then
            self.callbacks.onRegisterSuccess()
        end
        
    else
        local error = packet.data.payload or "Erreur d'inscription inconnue"
        print("[AUTH] Erreur d'inscription:", error)
        self.lastError = self:translateError(error)
        
        if self.callbacks.onRegisterError then
            self.callbacks.onRegisterError(self.lastError)
        end
    end
end

function AuthManager:loadCharacters()
    if not self.isAuthenticated or not _G.masterServer then
        return false
    end
    
    self:log("📋 ENVOI TOKEN - Debut loadCharacters")
    self:log("  email: " .. (self.currentUser.email or "nil"))
    self:log("  token disponible: " .. (self.currentUser.token and "oui" or "non"))
    if self.currentUser.token then
        self:log("  token longueur: " .. #self.currentUser.token)
        self:log("  token début: " .. string.sub(self.currentUser.token, 1, 30) .. "...")
    end
    
    local packet = {
        id = "list_character",
        data = {
            email = self.currentUser.email,
            token = self.currentUser.token
        }
    }
    
    self:log("📤 Packet à envoyer:")
    self:log("  data.email: " .. (packet.data.email or "nil"))
    self:log("  data.token longueur: " .. (packet.data.token and #packet.data.token or 0))
    self:log("  data.token début: " .. (packet.data.token and string.sub(packet.data.token, 1, 30) .. "..." or "nil"))
    
    local serialized = _G.bitser.dumps(packet)
    self:log("📡 Données sérialisées longueur: " .. #serialized)
    
    _G.masterServer:send(serialized)
    
    return true
end

function AuthManager:handleCharacterList(packet)
    if packet.data.type == "success" then
        print("[AUTH] Message reçu du serveur:", packet.id)
        
        if type(packet.data.payload) == "table" then
            print("[AUTH] Personnages chargés:", #packet.data.payload)
            self.currentUser.characters = packet.data.payload
        else
            print("[AUTH] ERREUR: Payload n'est pas une table, type:", type(packet.data.payload))
            self.currentUser.characters = {}
        end
        
        -- Synchroniser les données globales
        self:syncGlobalUser()
        
        if self.callbacks.onCharactersLoaded then
            self.callbacks.onCharactersLoaded(self.currentUser.characters)
        end
    else
        print("[AUTH] Erreur chargement personnages")
    end
end

function AuthManager:selectCharacter(characterName)
    if not self.isAuthenticated or not _G.masterServer then
        self:log("❌ Erreur: Non authentifié ou pas de connexion au master server")
        return false
    end
    
    self:log("🎮 SÉLECTION PERSONNAGE - Debut selectCharacter")
    self:log("  nom: " .. (characterName or "nil"))
    self:log("  email: " .. (self.currentUser.email or "nil"))
    self:log("  token disponible: " .. (self.currentUser.token and "oui" or "non"))
    if self.currentUser.token then
        self:log("  token longueur: " .. #self.currentUser.token)
        self:log("  token début: " .. string.sub(self.currentUser.token, 1, 30) .. "...")
    end
    
    local packet = {
        id = "play",
        data = {
            characterName = characterName,
            email = self.currentUser.email,
            token = self.currentUser.token
        }
    }
    
    self:log("📤 Packet play à envoyer:")
    self:log("  id: " .. packet.id)
    self:log("  data.characterName: " .. (packet.data.characterName or "nil"))
    self:log("  data.characterName: " .. (packet.data.characterName or "nil"))
    self:log("  data.email: " .. (packet.data.email or "nil"))
    self:log("  data.token longueur: " .. (packet.data.token and #packet.data.token or 0))
    
    local serialized = _G.bitser.dumps(packet)
    self:log("📡 Données play sérialisées longueur: " .. #serialized)
    
    _G.masterServer:send(serialized)
    
    return true
end

function AuthManager:handleWorldJoin(packet)
    if packet.data.type == "success" then
        local worldInfo = packet.data.payload.world
        print("[AUTH] Rejoindre le monde:", worldInfo.name)
        
        -- S'assurer que _G.user est synchronisé
        self:syncGlobalUser()
        
        -- Sauvegarder le personnage sélectionné
        _G.user.selectedCharacter = packet.data.payload.characterName
        
        -- Créer l'instance globale du WorldServer (sans en être propriétaire)
        self:createWorldServer(worldInfo, packet.data.payload.characterName)
        
        if self.callbacks.onWorldJoin then
            self.callbacks.onWorldJoin(worldInfo, packet.data.payload.characterName)
        end
    else
        print("[AUTH] Erreur lors du join monde:", packet.data.payload or "Erreur inconnue")
    end
end

-- Méthode pour créer le WorldServer global (AuthManager n'en est pas propriétaire)
function AuthManager:createWorldServer(worldInfo, characterName)
    print("[AUTH] Création du WorldServer global pour:", characterName)
    
    -- Créer l'instance globale du WorldServer
    local WorldServer = require(_G.engineDir .. "world_server")
    _G.worldServer = WorldServer:new(characterName)
    
    -- Configurer la connexion au monde
    _G.worldServer:connect(worldInfo.ip, worldInfo.port)
    
    print("[AUTH] WorldServer global créé et connecté à", worldInfo.ip .. ":" .. worldInfo.port)
end

function AuthManager:createCharacter(characterData)
    -- Valider l'état d'authentification et synchroniser
    if not self:validateAuthState() then
        return false
    end
    
    if not _G.masterServer then
        self:log("❌ Erreur: Pas de connexion au serveur")
        return false
    end
    
    -- Gérer les anciens appels avec 2 paramètres
    if type(characterData) == "string" then
        local characterName = characterData
        local clan = arguments and arguments[1] or "Neutral"
        characterData = {
            name = characterName,
            clan = clan,
            stats = {
                force = 13,
                intelligence = 13,
                speed = 13,
                agility = 13
            }
        }
    end
    
    self:log("👤 CREATION PERSONNAGE - Debut createCharacter")
    self:log("  nom: " .. (characterData.name or "nil"))
    self:log("  clan: " .. (characterData.clan or "Neutral"))
    self:log("  email: " .. (self.currentUser.email or "nil"))
    self:log("  token disponible: " .. (self.currentUser.token and "oui" or "non"))
    if self.currentUser.token then
        self:log("  token longueur: " .. #self.currentUser.token)
        self:log("  token début: " .. string.sub(self.currentUser.token, 1, 30) .. "...")
    end
    
    local packet = {
        id = "create_character",
        data = {
            email = self.currentUser.email,
            token = self.currentUser.token,
            characterName = characterData.name,
            clan = characterData.clan or "Neutral",
            stats = characterData.stats
        }
    }
    
    self:log("📤 Packet création à envoyer:")
    self:log("  data.email: " .. (packet.data.email or "nil"))
    self:log("  data.token longueur: " .. (packet.data.token and #packet.data.token or 0))
    self:log("  data.token début: " .. (packet.data.token and string.sub(packet.data.token, 1, 30) .. "..." or "nil"))
    self:log("  data.characterName: " .. (packet.data.characterName or "nil"))
    
    local serialized = _G.bitser.dumps(packet)
    self:log("📡 Données création sérialisées longueur: " .. #serialized)
    
    _G.masterServer:send(serialized)
    
    return true
end

function AuthManager:handleCharacterCreation(packet)
    if packet.data.type == "success" then
        print("[AUTH] Personnage créé avec succès")
        
        -- Recharger automatiquement la liste des personnages
        self:loadCharacters()
        
        if self.callbacks.onCharacterCreated then
            self.callbacks.onCharacterCreated(packet.data.payload)
        end
    else
        local error = packet.data.payload or "Erreur de création de personnage"
        print("[AUTH] Erreur de création:", error)
        self.lastError = self:translateError(error)
        
        if self.callbacks.onCharacterCreationError then
            self.callbacks.onCharacterCreationError(self.lastError)
        end
    end
end

function AuthManager:deleteCharacter(characterName)
    if not self.isAuthenticated or not _G.masterServer then
        return false
    end
    
    print("[AUTH] Suppression du personnage:", characterName)
    
    _G.masterServer:send(_G.bitser.dumps({
        id = "delete_character",
        data = {
            email = self.currentUser.email,
            token = self.currentUser.token,
            characterName = characterName
        }
    }))
    
    return true
end

function AuthManager:handleCharacterDeletion(packet)
    if packet.data.type == "success" then
        print("[AUTH] Personnage supprimé avec succès")
        
        -- Recharger automatiquement la liste des personnages
        self:loadCharacters()
        
        if self.callbacks.onCharacterDeleted then
            self.callbacks.onCharacterDeleted()
        end
    else
        local error = packet.data.payload or "Erreur de suppression de personnage"
        print("[AUTH] Erreur de suppression:", error)
        self.lastError = self:translateError(error)
        
        if self.callbacks.onCharacterDeleteError then
            self.callbacks.onCharacterDeleteError(self.lastError)
        end
    end
end

function AuthManager:playCharacter(characterName)
    return self:selectCharacter(characterName)
end

function AuthManager:logout()
    if not self.isAuthenticated or not _G.masterServer then
        return
    end
    
    print("[AUTH] Déconnexion")
    
    _G.masterServer:send(_G.bitser.dumps({
        id = "logout",
        data = {
            email = self.currentUser.email,
            token = self.currentUser.token
        }
    }))
    
    -- Supprimer le token sauvegardé
    self:clearSavedToken()
    
    -- Nettoyer les données locales
    self.isAuthenticated = false
    self.currentUser = {
        email = nil,
        token = nil,
        characters = {}
    }
    
    -- Nettoyer les globals
    _G.user = nil
    
    if self.callbacks.onLogout then
        self.callbacks.onLogout()
    end
end

function AuthManager:translateError(error)
    local translations = {
        ["invalid_password"] = "Mot de passe incorrect",
        ["user_not_found"] = "Utilisateur non trouvé",
        ["email_already_exists"] = "Cette adresse email est déjà utilisée",
        ["character_with_same_name_already_exist"] = "Ce nom de personnage existe déjà",
        ["invalid_token"] = "Session expirée, veuillez vous reconnecter"
    }
    
    return translations[error] or error
end

function AuthManager:update(dt)
    if _G.masterServer then
        _G.masterServer:update(dt)
    end
end

function AuthManager:isLoggedIn()
    return self.isAuthenticated and self.currentUser.token ~= nil
end

function AuthManager:getCurrentUser()
    return self.currentUser
end

function AuthManager:getLastError()
    return self.lastError
end

function AuthManager:clearError()
    self.lastError = nil
end

-- Synchroniser _G.user avec currentUser
function AuthManager:syncGlobalUser()
    if not _G.user then
        _G.user = {}
    end
    _G.user.email = self.currentUser.email
    _G.user.token = self.currentUser.token
    _G.user.characters = self.currentUser.characters or {}
    print("[AUTH] Global user synchronisé")
end

-- Vérifier et corriger l'état d'authentification
function AuthManager:validateAuthState()
    if self.isAuthenticated and self.currentUser.token then
        self:syncGlobalUser()
        return true
    else
        print("[AUTH] État d'authentification invalide")
        print("[AUTH] isAuthenticated:", self.isAuthenticated)
        print("[AUTH] currentUser.token:", self.currentUser.token and "existe" or "nil")
        return false
    end
end

-- Méthodes pour configurer les callbacks
function AuthManager:onConnected(callback)
    self.callbacks.onConnected = callback
end

function AuthManager:onDisconnected(callback)
    self.callbacks.onDisconnected = callback
end

function AuthManager:onLoginSuccess(callback)
    self.callbacks.onLoginSuccess = callback
end

function AuthManager:onLoginError(callback)
    self.callbacks.onLoginError = callback
end

function AuthManager:onRegisterSuccess(callback)
    self.callbacks.onRegisterSuccess = callback
end

function AuthManager:onRegisterError(callback)
    self.callbacks.onRegisterError = callback
end

function AuthManager:onCharactersLoaded(callback)
    self.callbacks.onCharactersLoaded = callback
end

function AuthManager:onWorldJoin(callback)
    self.callbacks.onWorldJoin = callback
end

function AuthManager:onCharacterCreated(callback)
    self.callbacks.onCharacterCreated = callback
end

function AuthManager:onCharacterCreationError(callback)
    self.callbacks.onCharacterCreationError = callback
end

function AuthManager:onCharacterDeleted(callback)
    self.callbacks.onCharacterDeleted = callback
end

function AuthManager:onCharacterDeleteError(callback)
    self.callbacks.onCharacterDeleteError = callback
end

function AuthManager:onLogout(callback)
    self.callbacks.onLogout = callback
end

-- Nouveaux callbacks pour l'auto-login
function AuthManager:onTokenLoadSuccess(callback)
    self.callbacks.onTokenLoadSuccess = callback
end

function AuthManager:onTokenLoadError(callback)
    self.callbacks.onTokenLoadError = callback
end

function AuthManager:onAutoLoginAttempt(callback)
    self.callbacks.onAutoLoginAttempt = callback
end

-- Méthode new() supprimée car la classe utilise middleclass

function AuthManager:log(message)
    local logMessage = "[AUTH] " .. message
    print(logMessage)
    
    -- Intégrer avec le système de debug si disponible
    if _G.addDebugLog then
        _G.addDebugLog(message)
    end
end

-- Ancienne fonction onMessage supprimée - remplacée par handleServerMessage

return AuthManager 
