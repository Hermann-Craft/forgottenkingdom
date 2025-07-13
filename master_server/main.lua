_G.baseDir      = (...):match("(.-)[^%.]+$")
_G.libDir       = _G.baseDir .. "lib."

_G.Json = require(_G.libDir .. "json")
local TcpServer = require(_G.libDir .. "tcp_server"):new()
local Redis = require(_G.libDir .. "redis")
_G.bitser = require(_G.libDir .. "bitser")
local Utils = require(_G.libDir .. "utils")

-- Nouveaux modules de sécurité
local AuthUtils = require(_G.libDir .. "auth-utils")
local Validators = require(_G.libDir .. "validators")
local RateLimiter = require(_G.libDir .. "rate-limiter")
local Serializer = require(_G.libDir .. "serializer")
local TokenUtils = require(_G.libDir .. "token-utils")

_G.uuid = function ()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and love.math.random(0, 0xf) or love.math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

_G.RedisClient = Redis.connect("127.0.0.1", 6379)

-- Migration des données existantes vers le nouveau format sécurisé
function migrateExistingData()
    print("[MIGRATION] Mise à jour des données existantes...")
    
    -- Migrer le mot de passe hardcodé vers un hash sécurisé
    local existingUser = RedisClient:hgetall("users:baw.developpement@gmail.com")
    if existingUser and existingUser.password == "123" then
        local hashedPassword = AuthUtils.hashPassword("123")
        RedisClient:hset("users:baw.developpement@gmail.com", "password", hashedPassword)
        RedisClient:hset("users:baw.developpement@gmail.com", "created_at", os.time())
        RedisClient:hset("users:baw.developpement@gmail.com", "last_login", os.time())
        RedisClient:hset("users:baw.developpement@gmail.com", "username", "TestUser")
        print("[MIGRATION] Mot de passe migré vers hash sécurisé")
    end
    
    -- Créer les index pour les noms d'utilisateur
    if not RedisClient:sismember("usernames", "TestUser") then
        RedisClient:sadd("usernames", "TestUser")
    end
    
    print("[MIGRATION] Migration terminée")
end

-- Initialisation des données de test
function initializeTestData()
    -- Utilisateur de test
    RedisClient:hset("users:baw.developpement@gmail.com", "email", "baw.developpement@gmail.com")
    RedisClient:hset("users:baw.developpement@gmail.com", "password", "123")
    RedisClient:hset("users:baw.developpement@gmail.com", "token", "")
    if (RedisClient:sismember("users", "baw.developpement@gmail.com") == false) then
        RedisClient:sadd("users", "baw.developpement@gmail.com")
    end
    
    -- Personnages de test
    RedisClient:hset("character:hello", "name", "hello")
    RedisClient:hset("character:hello", "owner", "baw.developpement@gmail.com")
    RedisClient:hset("character:yeah", "name", "yeah")
    RedisClient:hset("character:yeah", "owner", "baw.developpement@gmail.com")
    if (RedisClient:sismember("characters:baw.developpement@gmail.com", "character:hello") == false) then
        RedisClient:sadd("characters:baw.developpement@gmail.com", "character:hello")
    end
    if (RedisClient:sismember("characters:baw.developpement@gmail.com", "character:yeah") == false) then
        RedisClient:sadd("characters:baw.developpement@gmail.com", "character:yeah")
    end
    
    -- Mondes de jeu
    RedisClient:hset("world:nexus", "ip", "192.168.1.58")
    RedisClient:hset("world:nexus", "port", "8082")
    RedisClient:hset("world:nexus", "default", true)

    RedisClient:hset("world:realm_pvp", "ip", "127.0.0.1")
    RedisClient:hset("world:realm_pvp", "port", "8083")

    RedisClient:hset("world:realm_pve", "ip", "127.0.0.1")
    RedisClient:hset("world:realm_pve", "port", "8084")

    RedisClient:hset("world:guild", "ip", "127.0.0.1")
    RedisClient:hset("world:guild", "port", "8085")
    
    if (RedisClient:sismember("worlds", "world:nexus") == false) then
        RedisClient:sadd("worlds", "world:nexus")
    end
    if (RedisClient:sismember("worlds", "world:realm_pvp") == false) then
        RedisClient:sadd("worlds", "world:realm_pvp")
    end
    if (RedisClient:sismember("worlds", "world:realm_pve") == false) then
        RedisClient:sadd("worlds", "world:realm_pve")
    end
    if (RedisClient:sismember("worlds", "world:realm_guild") == false) then
        RedisClient:sadd("worlds", "world:realm_guild")
    end
    
    -- Migration des données existantes
    migrateExistingData()
end

-- Fonction d'aide pour envoyer une réponse
function sendResponse(clientid, packetId, success, payload, error)
    local response = {
        id = packetId,
        data = {
            type = success and "success" or "error",
            payload = success and payload or error
        }
    }
    
    -- Debug pour les réponses de liste de personnages
    if packetId == "list_character" and success then
        print("[SEND_RESPONSE] Envoi liste personnages")
        print("[SEND_RESPONSE] Type payload:", type(payload))
        print("[SEND_RESPONSE] Nombre d'éléments:", #payload)
        print("[SEND_RESPONSE] Structure response.data.payload:", type(response.data.payload))
    end
    
    TcpServer:send(_G.bitser.dumps(response), clientid)
end

-- Fonction d'aide pour vérifier un token
function verifyUserToken(email, tokenToVerify)
    print("[TOKEN DEBUG] Vérification token pour: " .. (email or "nil"))
    print("[TOKEN DEBUG] Token reçu longueur: " .. (tokenToVerify and #tokenToVerify or 0))
    
    if not email or not tokenToVerify then
        print("[TOKEN DEBUG] ❌ Email ou token manquant")
        return false, "Email et token requis"
    end
    
    local user = RedisClient:hgetall("users:" .. email)
    if not user or not user.email then
        print("[TOKEN DEBUG] ❌ Utilisateur non trouvé: " .. email)
        return false, "Utilisateur non trouvé"
    end
    
    print("[TOKEN DEBUG] Token stocké longueur: " .. (user.token and #user.token or 0))
    print("[TOKEN DEBUG] Token reçu format: " .. (tokenToVerify:find('"typ":"JWT"') and "JSON" or "bitser"))
    print("[TOKEN DEBUG] Token stocké format: " .. (user.token:find('"typ":"JWT"') and "JSON" or "bitser"))
    
    -- Utiliser TokenUtils pour comparer les tokens peu importe leur format
    if not TokenUtils.compareTokens(tokenToVerify, user.token) then
        print("[TOKEN DEBUG] ❌ Tokens ne correspondent pas après normalisation")
        print("[TOKEN DEBUG] Token reçu début: " .. string.sub(tokenToVerify or "", 1, 50) .. "...")
        print("[TOKEN DEBUG] Token stocké début: " .. string.sub(user.token or "", 1, 50) .. "...")
        return false, "Token invalide"
    end
    
    -- Vérifier l'expiration du token
    if TokenUtils.isTokenExpired(user.token) then
        print("[TOKEN DEBUG] ❌ Token expiré")
        return false, "Token expiré"
    end
    
    print("[TOKEN DEBUG] ✅ Token valide après normalisation")
    return true, user
end

-- Initialisation
initializeTestData()

TcpServer.handshake = "00000"
TcpServer:listen(8080)

print("[MASTER SERVER] Démarrage sur le port 8080...")
print("[MASTER SERVER] Modules de sécurité chargés")

TcpServer.callbacks.recv = function (data, clientid)
    local packet = _G.bitser.loads(data)
    local ip = RateLimiter.getClientIP(clientid)
    
    print("[MASTER SERVER] Packet reçu:", packet.id, "de", ip)
    
    -- Sanitiser les données d'entrée
    if packet.data then
        packet.data = Validators.sanitizeInputData(packet.data)
    end
    
    -- === NOUVELLE ROUTE: Inscription d'utilisateur ===
    if packet.id == "register_user" then
        -- Vérifier le rate limiting
        local rateLimitOK, rateLimitError = RateLimiter.checkRequest(ip, "register")
        if not rateLimitOK then
            RateLimiter.recordAttempt(ip, "register", false)
            sendResponse(clientid, "register_user", false, nil, rateLimitError)
            return
        end
        
        -- Valider les données
        local dataValid, validatedData = Validators.validateRegistrationData(packet.data)
        if not dataValid then
            RateLimiter.recordAttempt(ip, "register", false)
            AuthUtils.logAuthAttempt(packet.data.email or "unknown", false, ip, validatedData)
            sendResponse(clientid, "register_user", false, nil, validatedData)
            return
        end
        
        -- Vérifier si l'email existe déjà
        local emailExists = Validators.checkEmailExists(validatedData.email, RedisClient)
        if emailExists then
            RateLimiter.recordAttempt(ip, "register", false)
            AuthUtils.logAuthAttempt(validatedData.email, false, ip, "Email déjà utilisé")
            sendResponse(clientid, "register_user", false, nil, "Cet email est déjà utilisé")
            return
        end
        
        -- Vérifier si le nom d'utilisateur existe déjà (si fourni)
        if validatedData.username then
            local usernameExists = Validators.checkUsernameExists(validatedData.username, RedisClient)
            if usernameExists then
                RateLimiter.recordAttempt(ip, "register", false)
                AuthUtils.logAuthAttempt(validatedData.email, false, ip, "Nom d'utilisateur déjà utilisé")
                sendResponse(clientid, "register_user", false, nil, "Ce nom d'utilisateur est déjà utilisé")
                return
            end
        end
        
        -- Créer l'utilisateur
        local hashedPassword = AuthUtils.hashPassword(validatedData.password)
        local currentTime = os.time()
        
        -- Sauvegarder en Redis
        RedisClient:hset("users:" .. validatedData.email, "email", validatedData.email)
        RedisClient:hset("users:" .. validatedData.email, "password", hashedPassword)
        RedisClient:hset("users:" .. validatedData.email, "token", "")
        RedisClient:hset("users:" .. validatedData.email, "created_at", currentTime)
        RedisClient:hset("users:" .. validatedData.email, "last_login", 0)
        
        if validatedData.username then
            RedisClient:hset("users:" .. validatedData.email, "username", validatedData.username)
            RedisClient:sadd("usernames", validatedData.username)
        end
        
        -- Ajouter aux index
        RedisClient:sadd("users", validatedData.email)
        
        -- Enregistrer le succès
        RateLimiter.recordAttempt(ip, "register", true)
        AuthUtils.logAuthAttempt(validatedData.email, true, ip, "Inscription réussie")
        
        sendResponse(clientid, "register_user", true, {
            email = validatedData.email,
            username = validatedData.username,
            message = "Inscription réussie"
        }, nil)
    
    -- === NOUVELLE ROUTE: Vérification email ===
    elseif packet.id == "check_email_exists" then
        if not packet.data or not packet.data.email then
            sendResponse(clientid, "check_email_exists", false, nil, "Email requis")
            return
        end
        
        local emailValid, emailOrError = Validators.validateEmail(packet.data.email)
        if not emailValid then
            sendResponse(clientid, "check_email_exists", false, nil, emailOrError)
            return
        end
        
        local exists = Validators.checkEmailExists(emailOrError, RedisClient)
        sendResponse(clientid, "check_email_exists", true, {
            email = emailOrError,
            exists = exists
        }, nil)
    
    -- === NOUVELLE ROUTE: Connexion par token ===
    elseif packet.id == "connect_with_token" then
        -- Vérifier le rate limiting
        local rateLimitOK, rateLimitError = RateLimiter.checkRequest(ip, "login")
        if not rateLimitOK then
            RateLimiter.recordAttempt(ip, "login", false)
            sendResponse(clientid, "connection", false, nil, rateLimitError)
            return
        end
        
        -- Valider les données
        if not packet.data or not packet.data.email or not packet.data.token then
            RateLimiter.recordAttempt(ip, "login", false)
            AuthUtils.logAuthAttempt(packet.data.email or "unknown", false, ip, "Email et token requis")
            sendResponse(clientid, "connection", false, nil, "Email et token requis")
            return
        end
        
        local email = Validators.sanitizeInputData({email = packet.data.email}).email
        local token = packet.data.token
        
        print("[TOKEN LOGIN] Tentative de connexion par token pour:", email)
        print("[TOKEN LOGIN] Token reçu longueur:", #token)
        
        -- Vérifier le token
        local tokenValid, userOrError = verifyUserToken(email, token)
        if not tokenValid then
            RateLimiter.recordAttempt(ip, "login", false)
            AuthUtils.logAuthAttempt(email, false, ip, userOrError)
            
            -- Messages spécifiques pour les erreurs de token
            local errorMessage = userOrError
            if userOrError:find("Token") then
                errorMessage = "Session expirée, veuillez vous reconnecter"
            end
            
            sendResponse(clientid, "connection", false, nil, errorMessage)
            return
        end
        
        -- Token valide, connexion réussie
        print("[TOKEN LOGIN] Connexion par token réussie pour:", email)
        
        -- Mettre à jour la dernière connexion
        RedisClient:hset("users:" .. email, "last_login", os.time())
        
        -- Enregistrer le succès
        RateLimiter.recordAttempt(ip, "login", true)
        AuthUtils.logAuthAttempt(email, true, ip, "Connexion par token réussie")
        
        sendResponse(clientid, "connection", true, {
            email = userOrError.email,
            token = userOrError.token,
            username = userOrError.username
        }, nil)
    
    -- === ROUTE MISE À JOUR: Connexion sécurisée ===
    elseif packet.id == "connect_with_password" then
        -- Vérifier le rate limiting
        local rateLimitOK, rateLimitError = RateLimiter.checkRequest(ip, "login")
        if not rateLimitOK then
            RateLimiter.recordAttempt(ip, "login", false)
            sendResponse(clientid, "connection", false, nil, rateLimitError)
            return
        end
        
        -- Valider les données
        local dataValid, validatedData = Validators.validateLoginData(packet.data)
        if not dataValid then
            RateLimiter.recordAttempt(ip, "login", false)
            AuthUtils.logAuthAttempt(packet.data.email or "unknown", false, ip, validatedData)
            sendResponse(clientid, "connection", false, nil, validatedData)
            return
        end
        
        -- Vérifier si l'utilisateur existe
        local userFound = RedisClient:sismember("users", validatedData.email)
        if userFound == false then
            RateLimiter.recordAttempt(ip, "login", false)
            AuthUtils.logAuthAttempt(validatedData.email, false, ip, "Utilisateur non trouvé")
            sendResponse(clientid, "connection", false, nil, "Email ou mot de passe incorrect")
            return
        end
        
        -- Récupérer l'utilisateur
        local user = RedisClient:hgetall("users:" .. validatedData.email)
        if not user or not user.email then
            RateLimiter.recordAttempt(ip, "login", false)
            AuthUtils.logAuthAttempt(validatedData.email, false, ip, "Données utilisateur corrompues")
            sendResponse(clientid, "connection", false, nil, "Erreur serveur")
            return
        end
        
        -- Vérifier le mot de passe
        local passwordValid = AuthUtils.verifyPassword(validatedData.password, user.password)
        if not passwordValid then
            RateLimiter.recordAttempt(ip, "login", false)
            AuthUtils.logAuthAttempt(validatedData.email, false, ip, "Mot de passe incorrect")
            sendResponse(clientid, "connection", false, nil, "Email ou mot de passe incorrect")
            return
        end
        
        -- Générer un nouveau token
        local newToken = AuthUtils.generateJWT(validatedData.email, 86400) -- 24 heures
        print("[TOKEN DEBUG] 🔑 Nouveau token généré pour: " .. validatedData.email)
        print("[TOKEN DEBUG] Token longueur: " .. #newToken)
        print("[TOKEN DEBUG] Token début: " .. string.sub(newToken, 1, 30) .. "...")
        
        RedisClient:hset("users:" .. validatedData.email, "token", newToken)
        RedisClient:hset("users:" .. validatedData.email, "last_login", os.time())
        
        -- Vérifier immédiatement le stockage
        local storedToken = RedisClient:hget("users:" .. validatedData.email, "token")
        if storedToken == newToken then
            print("[TOKEN DEBUG] ✅ Token stocké correctement en Redis")
        else
            print("[TOKEN DEBUG] ❌ ERREUR: Token mal stocké en Redis!")
            print("[TOKEN DEBUG] Généré: " .. string.sub(newToken, 1, 30) .. "...")
            print("[TOKEN DEBUG] Stocké: " .. (storedToken and string.sub(storedToken, 1, 30) .. "..." or "nil"))
        end
        
        -- Enregistrer le succès
        RateLimiter.recordAttempt(ip, "login", true)
        AuthUtils.logAuthAttempt(validatedData.email, true, ip, "Connexion réussie")
        
        sendResponse(clientid, "connection", true, {
            email = user.email,
            token = newToken,
            username = user.username
        }, nil)
    
    -- === ROUTE MISE À JOUR: Création de personnage sécurisée ===
    elseif packet.id == "create_character" then
        -- Valider les données
        local dataValid, validatedData = Validators.validateCharacterCreationData(packet.data)
        if not dataValid then
            sendResponse(clientid, "create_character", false, nil, validatedData)
            return
        end
        
        -- Vérifier le token
        local tokenValid, userOrError = verifyUserToken(validatedData.email, validatedData.token)
        if not tokenValid then
            sendResponse(clientid, "create_character", false, nil, userOrError)
            return
        end
        
        -- Vérifier si le nom de personnage existe déjà
        local nameExists = Validators.checkCharacterNameExists(validatedData.characterName, RedisClient)
        if nameExists then
            sendResponse(clientid, "create_character", false, nil, "Ce nom de personnage est déjà utilisé")
            return
        end
        
        -- Vérifier si l'utilisateur a déjà ce personnage
        if RedisClient:sismember("characters:" .. validatedData.email, "character:" .. validatedData.characterName) then
            sendResponse(clientid, "create_character", false, nil, "Vous avez déjà un personnage avec ce nom")
            return
        end
        
        -- Créer le personnage avec les stats personnalisées
        local newCharacter = {
            name = validatedData.characterName,
            clan = validatedData.clan,
            force = validatedData.stats and validatedData.stats.force or 10,
            intelligence = validatedData.stats and validatedData.stats.intelligence or 10,
            speed = validatedData.stats and validatedData.stats.speed or 10,
            agility = validatedData.stats and validatedData.stats.agility or 10,
            life = 100,
            wallet = 100,
            level = 1,
            experience = 0,
            created_at = os.time(),
            last_played = os.time()
        }
        
        -- Sauvegarder en Redis
        RedisClient:hset("character:" .. validatedData.characterName, "name", validatedData.characterName)
        RedisClient:hset("character:" .. validatedData.characterName, "owner", validatedData.email)
        RedisClient:hset("character:" .. validatedData.characterName, "data", Json:encode(newCharacter))
        RedisClient:sadd("characters:" .. validatedData.email, "character:" .. validatedData.characterName)
        
        print("[MASTER SERVER] Personnage créé:", validatedData.characterName, "pour", validatedData.email)
        
        sendResponse(clientid, "create_character", true, newCharacter, nil)
    
    -- === ROUTE MISE À JOUR: Liste des personnages sécurisée ===
    elseif packet.id == "list_character" then
        local email = packet.data and packet.data.email
        local token = packet.data and packet.data.token
        
        if not email or not token then
            sendResponse(clientid, "list_character", false, nil, "Email et token requis")
            return
        end
        
        -- Vérifier le token
        local tokenValid, userOrError = verifyUserToken(email, token)
        if not tokenValid then
            sendResponse(clientid, "list_character", false, nil, userOrError)
            return
        end
        
        -- Récupérer les personnages
        local characters = RedisClient:smembers("characters:" .. email)
        local charactersTable = {}

        print("[MASTER SERVER] Personnages trouvés pour", email, ":", #characters)

        for index, characterName in ipairs(characters) do
            local character = RedisClient:hgetall(characterName)
            if character and character.name then
                print("[MASTER SERVER] Personnage trouvé:", character.name)
                
                -- Désérialiser les données du personnage si elles existent
                if character.data then
                    print("[MASTER SERVER] Données brutes:", string.sub(character.data, 1, 100))
                    local success, decodedData = pcall(function()
                        return Json:decode(character.data)
                    end)
                    
                    if success and decodedData then
                        character.data = decodedData
                        print("[MASTER SERVER] Personnage désérialisé:", character.name, "avec données complètes")
                    else
                        print("[MASTER SERVER] Échec désérialisation pour:", character.name)
                        character.data = {}
                    end
                else
                    print("[MASTER SERVER] Aucune donnée pour:", character.name)
                    character.data = {}
                end
                
                charactersTable[index] = character
            end
        end
        
        print("[MASTER SERVER] Envoi de", #charactersTable, "personnages pour", email)
        print("[MASTER SERVER] Type de charactersTable:", type(charactersTable))
        print("[MASTER SERVER] Structure finale à envoyer:")
        for i, char in ipairs(charactersTable) do
            print("  [" .. i .. "] " .. char.name .. " - type data:", type(char.data))
        end
        
        sendResponse(clientid, "list_character", true, charactersTable, nil)
    
    -- === ROUTE MISE À JOUR: Jouer sécurisée ===
    elseif packet.id == "play" then
        local email = packet.data and packet.data.email
        local token = packet.data and packet.data.token
        local characterName = packet.data and packet.data.characterName
        
        if not email or not token or not characterName then
            sendResponse(clientid, "play", false, nil, "Email, token et nom de personnage requis")
            return
        end
        
        -- Vérifier le token
        local tokenValid, userOrError = verifyUserToken(email, token)
        if not tokenValid then
            sendResponse(clientid, "play", false, nil, userOrError)
            return
        end
        
        -- Vérifier que le personnage appartient à l'utilisateur
        if not RedisClient:sismember("characters:" .. email, "character:" .. characterName) then
            sendResponse(clientid, "play", false, nil, "Ce personnage ne vous appartient pas")
            return
        end
        
        -- Récupérer le monde
        local lastWorld = RedisClient:hget("character:" .. characterName, "lastWorld")
        if lastWorld then
            local worldInfo = RedisClient:hgetall("world:" .. lastWorld)
            if worldInfo and worldInfo.ip then
                sendResponse(clientid, "play", true, {
                    characterName = characterName,
                    world = {
                        name = lastWorld,
                        ip = worldInfo.ip,
                        port = worldInfo.port
                    }
                }, nil)
                return
            end
        end
        
        -- Monde par défaut
        local worlds = RedisClient:smembers("worlds")
        for index, worldName in ipairs(worlds) do
            local world = RedisClient:hgetall(worldName)
            if world.default == "true" then
                sendResponse(clientid, "play", true, {
                    characterName = characterName,
                    world = {
                        name = worldName,
                        ip = world.ip,
                        port = world.port
                    }
                }, nil)
                return
            end
        end
        
        sendResponse(clientid, "play", false, nil, "Aucun monde disponible")
    
    -- === NOUVELLE ROUTE: Déconnexion ===
    elseif packet.id == "logout" then
        local email = packet.data and packet.data.email
        local token = packet.data and packet.data.token
        
        if not email or not token then
            sendResponse(clientid, "logout", false, nil, "Email et token requis")
            return
        end
        
        -- Vérifier le token
        local tokenValid, userOrError = verifyUserToken(email, token)
        if not tokenValid then
            sendResponse(clientid, "logout", false, nil, userOrError)
            return
        end
        
        -- Invalider le token
        RedisClient:hset("users:" .. email, "token", "")
        
        AuthUtils.logAuthAttempt(email, true, ip, "Déconnexion")
        sendResponse(clientid, "logout", true, {message = "Déconnexion réussie"}, nil)
    
    -- === NOUVELLE ROUTE: Supprimer un personnage ===
    elseif packet.id == "delete_character" then
        local email = packet.data and packet.data.email
        local token = packet.data and packet.data.token
        local characterName = packet.data and packet.data.characterName
        
        if not email or not token or not characterName then
            sendResponse(clientid, "delete_character", false, nil, "Email, token et nom de personnage requis")
            return
        end
        
        -- Vérifier le token
        local tokenValid, userOrError = verifyUserToken(email, token)
        if not tokenValid then
            sendResponse(clientid, "delete_character", false, nil, userOrError)
            return
        end
        
        -- Vérifier que le personnage appartient à l'utilisateur
        if not RedisClient:sismember("characters:" .. email, "character:" .. characterName) then
            sendResponse(clientid, "delete_character", false, nil, "Ce personnage ne vous appartient pas")
            return
        end
        
        -- Supprimer le personnage
        RedisClient:del("character:" .. characterName)
        RedisClient:srem("characters:" .. email, "character:" .. characterName)
        
        -- Supprimer de l'index des noms de personnages
        RedisClient:srem("characterNames", characterName)
        
        print("[MASTER SERVER] Personnage supprimé:", characterName, "pour", email)
        
        sendResponse(clientid, "delete_character", true, {message = "Personnage supprimé avec succès"}, nil)
    
    -- === NOUVELLE ROUTE: Statistiques du serveur (admin) ===
    elseif packet.id == "server_stats" then
        local stats = {
            rateLimiter = RateLimiter.getAllStats(),
            totalUsers = RedisClient:scard("users"),
            totalWorlds = RedisClient:scard("worlds"),
            uptime = os.time() - (startTime or os.time())
        }
        
        sendResponse(clientid, "server_stats", true, stats, nil)
    
    else
        sendResponse(clientid, packet.id, false, nil, "Route inconnue: " .. packet.id)
    end
end

TcpServer.callbacks.connect = function (clientid)
    local ip = RateLimiter.getClientIP(clientid)
    print("[MASTER SERVER] Client connecté:", clientid, "IP:", ip)
    
    TcpServer:send(_G.bitser.dumps({
        id = "request_identity"
    }), clientid)
end

TcpServer.callbacks.disconnect = function (clientid)
    local ip = RateLimiter.getClientIP(clientid)
    print("[MASTER SERVER] Client déconnecté:", clientid, "IP:", ip)
end

-- Heure de démarrage pour les statistiques
local startTime = os.time()

function love.update(dt)
    TcpServer:update(dt)
    
    -- Nettoyage périodique du rate limiter
    if math.random() < 0.001 then -- 0.1% de chance chaque frame
        RateLimiter.cleanup()
    end
end
