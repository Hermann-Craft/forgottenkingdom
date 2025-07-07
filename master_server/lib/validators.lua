local Validators = {}

-- Validation email avec regex
function Validators.validateEmail(email)
    if not email or type(email) ~= "string" then
        return false, "Email requis"
    end
    
    -- Trim les espaces
    email = string.gsub(email, "^%s+", "")
    email = string.gsub(email, "%s+$", "")
    
    -- Vérifier la longueur
    if #email < 3 then
        return false, "Email trop court"
    end
    
    if #email > 254 then
        return false, "Email trop long"
    end
    
    -- Regex basique pour email
    local pattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+%.[a-zA-Z][a-zA-Z]+$"
    if not string.match(email, pattern) then
        return false, "Format d'email invalide"
    end
    
    return true, email
end

-- Validation nom d'utilisateur
function Validators.validateUsername(username)
    if not username or type(username) ~= "string" then
        return false, "Nom d'utilisateur requis"
    end
    
    -- Trim les espaces
    username = string.gsub(username, "^%s+", "")
    username = string.gsub(username, "%s+$", "")
    
    -- Vérifier la longueur
    if #username < 3 then
        return false, "Le nom d'utilisateur doit contenir au moins 3 caractères"
    end
    
    if #username > 20 then
        return false, "Le nom d'utilisateur ne peut pas dépasser 20 caractères"
    end
    
    -- Vérifier les caractères autorisés (lettres, chiffres, underscore)
    if not string.match(username, "^[a-zA-Z0-9_]+$") then
        return false, "Le nom d'utilisateur ne peut contenir que des lettres, chiffres et underscores"
    end
    
    -- Vérifier qu'il commence par une lettre
    if not string.match(username, "^[a-zA-Z]") then
        return false, "Le nom d'utilisateur doit commencer par une lettre"
    end
    
    return true, username
end

-- Validation nom de personnage
function Validators.validateCharacterName(characterName)
    if not characterName or type(characterName) ~= "string" then
        return false, "Nom de personnage requis"
    end
    
    -- Trim les espaces
    characterName = string.gsub(characterName, "^%s+", "")
    characterName = string.gsub(characterName, "%s+$", "")
    
    -- Vérifier la longueur
    if #characterName < 2 then
        return false, "Le nom de personnage doit contenir au moins 2 caractères"
    end
    
    if #characterName > 16 then
        return false, "Le nom de personnage ne peut pas dépasser 16 caractères"
    end
    
    -- Vérifier les caractères autorisés (lettres uniquement)
    if not string.match(characterName, "^[a-zA-Z]+$") then
        return false, "Le nom de personnage ne peut contenir que des lettres"
    end
    
    -- Capitaliser la première lettre
    characterName = string.upper(string.sub(characterName, 1, 1)) .. string.lower(string.sub(characterName, 2))
    
    return true, characterName
end

-- Validation clan
function Validators.validateClan(clan)
    local validClans = {
        "Alliance",
        "Horde", 
        "Steampunk",
        "Neutral"
    }
    
    if not clan or type(clan) ~= "string" then
        return false, "Clan requis"
    end
    
    -- Vérifier si le clan existe
    for _, validClan in ipairs(validClans) do
        if clan == validClan then
            return true, clan
        end
    end
    
    return false, "Clan invalide. Clans disponibles: " .. table.concat(validClans, ", ")
end

-- Validation des données d'inscription
function Validators.validateRegistrationData(data)
    if not data or type(data) ~= "table" then
        return false, "Données d'inscription invalides"
    end
    
    -- Valider email
    local emailValid, emailOrError = Validators.validateEmail(data.email)
    if not emailValid then
        return false, emailOrError
    end
    
    -- Valider mot de passe
    local AuthUtils = require(_G.libDir .. "auth-utils")
    local passwordValid, passwordError = AuthUtils.validatePasswordStrength(data.password)
    if not passwordValid then
        return false, passwordError
    end
    
    -- Valider nom d'utilisateur (optionnel)
    local username = data.username
    if username then
        local usernameValid, usernameOrError = Validators.validateUsername(username)
        if not usernameValid then
            return false, usernameOrError
        end
        username = usernameOrError
    end
    
    return true, {
        email = emailOrError,
        password = data.password,
        username = username
    }
end

-- Validation des données de connexion
function Validators.validateLoginData(data)
    if not data or type(data) ~= "table" then
        return false, "Données de connexion invalides"
    end
    
    -- Valider email
    local emailValid, emailOrError = Validators.validateEmail(data.email)
    if not emailValid then
        return false, emailOrError
    end
    
    -- Valider mot de passe (vérifier qu'il existe)
    if not data.password or type(data.password) ~= "string" or #data.password == 0 then
        return false, "Mot de passe requis"
    end
    
    return true, {
        email = emailOrError,
        password = data.password
    }
end

-- Validation des statistiques de personnage
function Validators.validateCharacterStats(stats)
    if not stats or type(stats) ~= "table" then
        return false, "Statistiques invalides"
    end
    
    local validStats = {"force", "intelligence", "speed", "agility"}
    local validatedStats = {}
    
    for _, statName in ipairs(validStats) do
        local statValue = stats[statName]
        
        if statValue then
            if type(statValue) ~= "number" then
                return false, "La statistique " .. statName .. " doit être un nombre"
            end
            
            if statValue < 1 or statValue > 100 then
                return false, "La statistique " .. statName .. " doit être entre 1 et 100"
            end
            
            validatedStats[statName] = math.floor(statValue)
        else
            validatedStats[statName] = 10 -- Valeur par défaut
        end
    end
    
    -- Vérifier le total des points (optionnel, peut être configuré)
    local totalPoints = validatedStats.force + validatedStats.intelligence + validatedStats.speed + validatedStats.agility
    if totalPoints > 200 then
        return false, "Le total des statistiques ne peut pas dépasser 200 points"
    end
    
    return true, validatedStats
end

-- Validation des données de création de personnage
function Validators.validateCharacterCreationData(data)
    if not data or type(data) ~= "table" then
        return false, "Données de création de personnage invalides"
    end
    
    -- Valider nom de personnage
    local nameValid, nameOrError = Validators.validateCharacterName(data.characterName)
    if not nameValid then
        return false, nameOrError
    end
    
    -- Valider clan (optionnel)
    local clan = data.clan or "Neutral"
    local clanValid, clanOrError = Validators.validateClan(clan)
    if not clanValid then
        return false, clanOrError
    end
    
    -- Valider email du propriétaire
    local emailValid, emailOrError = Validators.validateEmail(data.email)
    if not emailValid then
        return false, emailOrError
    end
    
    -- Valider token
    if not data.token or type(data.token) ~= "string" or #data.token == 0 then
        return false, "Token d'authentification requis"
    end
    
    -- Valider les statistiques (optionnel)
    local validatedStats = nil
    if data.stats then
        local statsValid, statsOrError = Validators.validateCharacterStats(data.stats)
        if not statsValid then
            return false, statsOrError
        end
        validatedStats = statsOrError
    end
    
    return true, {
        characterName = nameOrError,
        clan = clanOrError,
        email = emailOrError,
        token = data.token,
        stats = validatedStats
    }
end

-- Validation générale d'un token
function Validators.validateToken(token)
    if not token or type(token) ~= "string" or #token == 0 then
        return false, "Token requis"
    end
    
    -- Vérifier le format basique
    if #token < 10 then
        return false, "Token invalide"
    end
    
    return true, token
end

-- Sanitiser les données d'entrée
function Validators.sanitizeInputData(data)
    if not data or type(data) ~= "table" then
        return {}
    end
    
    local AuthUtils = require(_G.libDir .. "auth-utils")
    local sanitized = {}
    
    -- Champs à NE PAS sanitiser (tokens JWT, etc.)
    local excludeFromSanitization = {
        ["token"] = true,
        ["jwt"] = true,
        ["auth_token"] = true,
        ["access_token"] = true
    }
    
    for key, value in pairs(data) do
        if type(value) == "string" and not excludeFromSanitization[key] then
            sanitized[key] = AuthUtils.sanitizeString(value)
        else
            sanitized[key] = value
        end
    end
    
    return sanitized
end

-- Vérifier si l'email existe déjà
function Validators.checkEmailExists(email, redisClient)
    if not email or not redisClient then
        return false, "Paramètres manquants"
    end
    
    local exists = redisClient:sismember("users", email)
    return exists ~= false, exists and "Email déjà utilisé" or "Email disponible"
end

-- Vérifier si le nom d'utilisateur existe déjà
function Validators.checkUsernameExists(username, redisClient)
    if not username or not redisClient then
        return false, "Paramètres manquants"
    end
    
    local exists = redisClient:sismember("usernames", username)
    return exists ~= false, exists and "Nom d'utilisateur déjà utilisé" or "Nom d'utilisateur disponible"
end

-- Vérifier si le nom de personnage existe déjà
function Validators.checkCharacterNameExists(characterName, redisClient)
    if not characterName or not redisClient then
        return false, "Paramètres manquants"
    end
    
    local exists = redisClient:exists("character:" .. characterName)
    
    if exists == true then
        return true, "Nom de personnage déjà utilisé"
    else
        return false, "Nom de personnage disponible"
    end
end

return Validators 
