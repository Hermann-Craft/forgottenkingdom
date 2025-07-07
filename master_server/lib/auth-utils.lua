local AuthUtils = {}

-- Utilitaire pour générer un hash sécurisé (simulation bcrypt)
function AuthUtils.hashPassword(password)
    -- Génération d'un salt aléatoire
    local salt = string.format("%08x", love.math.random(0, 0xFFFFFFFF))
    
    -- Hash simple (dans un vrai projet, utiliser bcrypt)
    local hash = ""
    for i = 1, #password do
        hash = hash .. string.format("%02x", (string.byte(password, i) + i) % 256)
    end
    
    -- Combiner salt et hash
    return salt .. ":" .. hash
end

-- Vérifier un mot de passe contre son hash
function AuthUtils.verifyPassword(password, hash)
    if not hash or not string.find(hash, ":") then
        return false
    end
    
    local salt, storedHash = hash:match("^([^:]+):(.+)$")
    if not salt or not storedHash then
        return false
    end
    
    -- Recalculer le hash avec le même salt
    local newHash = ""
    for i = 1, #password do
        newHash = newHash .. string.format("%02x", (string.byte(password, i) + i) % 256)
    end
    
    return newHash == storedHash
end

-- Générer un token JWT simplifié
function AuthUtils.generateJWT(email, expiresIn)
    expiresIn = expiresIn or 86400 -- 24 heures par défaut
    
    -- Créer JSON manuellement pour assurer la consistance
    local headerStr = '{"typ":"JWT","alg":"HS256"}'
    local payloadStr = string.format('{"email":"%s","iat":%d,"exp":%d}', 
        email, os.time(), os.time() + expiresIn)
    
    -- Signature simplifiée (dans un vrai projet, utiliser HMAC-SHA256)
    local signature = string.format("%08x", love.math.random(0, 0xFFFFFFFF))
    
    local token = headerStr .. "." .. payloadStr .. "." .. signature
    
    print("[JWT DEBUG] Token généré: " .. string.sub(token, 1, 50) .. "...")
    print("[JWT DEBUG] Header: " .. headerStr)
    print("[JWT DEBUG] Payload: " .. payloadStr)
    
    return token
end

-- Vérifier et décoder un token JWT
function AuthUtils.verifyJWT(token)
    if not token or not string.find(token, "%.") then
        return false, "Token invalide"
    end
    
    local parts = {}
    for part in string.gmatch(token, "([^%.]+)") do
        table.insert(parts, part)
    end
    
    if #parts ~= 3 then
        return false, "Format de token invalide"
    end
    
    local headerStr, payloadStr, signature = parts[1], parts[2], parts[3]
    
    print("[JWT VERIFY] Header: " .. headerStr)
    print("[JWT VERIFY] Payload: " .. payloadStr)
    
    -- Décoder le payload manuellement
    local email = payloadStr:match('"email":"([^"]+)"')
    local iat = tonumber(payloadStr:match('"iat":(%d+)'))
    local exp = tonumber(payloadStr:match('"exp":(%d+)'))
    
    if not email or not iat or not exp then
        return false, "Payload invalide - parsing échoué"
    end
    
    local payload = {
        email = email,
        iat = iat,
        exp = exp
    }
    
    print("[JWT VERIFY] Email décodé: " .. email)
    print("[JWT VERIFY] Expiration: " .. exp .. " (actuel: " .. os.time() .. ")")
    
    -- Vérifier l'expiration
    if exp < os.time() then
        return false, "Token expiré"
    end
    
    return true, payload
end

-- Générer un UUID pour les tokens
function AuthUtils.generateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and love.math.random(0, 0xf) or love.math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Sanitiser une chaîne pour éviter les injections
function AuthUtils.sanitizeString(str)
    if not str then return "" end
    
    -- Supprimer les caractères dangereux
    str = string.gsub(str, "[<>\"'&]", "")
    
    -- Trim les espaces
    str = string.gsub(str, "^%s+", "")
    str = string.gsub(str, "%s+$", "")
    
    return str
end

-- Vérifier la force d'un mot de passe
function AuthUtils.validatePasswordStrength(password)
    if not password or #password < 6 then
        return false, "Le mot de passe doit contenir au moins 6 caractères"
    end
    
    local hasLetter = string.find(password, "[a-zA-Z]")
    local hasDigit = string.find(password, "[0-9]")
    
    if not hasLetter then
        return false, "Le mot de passe doit contenir au moins une lettre"
    end
    
    if not hasDigit then
        return false, "Le mot de passe doit contenir au moins un chiffre"
    end
    
    return true, "Mot de passe valide"
end

-- Logs d'audit des connexions
function AuthUtils.logAuthAttempt(email, success, ip, reason)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local status = success and "SUCCESS" or "FAILED"
    local logEntry = string.format("[%s] AUTH_%s: %s from %s", timestamp, status, email, ip or "unknown")
    
    if not success and reason then
        logEntry = logEntry .. " - " .. reason
    end
    
    print("[AUTH LOG] " .. logEntry)
    
    -- Dans un vrai projet, écrire dans un fichier de log
    -- local file = io.open("auth.log", "a")
    -- if file then
    --     file:write(logEntry .. "\n")
    --     file:close()
    -- end
end

return AuthUtils 
