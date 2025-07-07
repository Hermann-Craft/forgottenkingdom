local RateLimiter = {}

-- Cache en mémoire pour les tentatives (dans un vrai projet, utiliser Redis)
local attempts = {}
local blockedIPs = {}

-- Configuration par défaut
local config = {
    maxAttempts = 5,          -- Nombre max de tentatives
    windowTime = 300,         -- Fenêtre de temps en secondes (5 minutes)
    blockDuration = 900,      -- Durée de blocage en secondes (15 minutes)
    cleanupInterval = 600     -- Intervalle de nettoyage en secondes (10 minutes)
}

-- Dernière fois que le nettoyage a été fait
local lastCleanup = os.time()

-- Nettoyer les anciennes tentatives
function RateLimiter.cleanup()
    local currentTime = os.time()
    
    -- Nettoyer les tentatives expirées
    for ip, data in pairs(attempts) do
        local newAttempts = {}
        for _, attempt in ipairs(data.attempts) do
            if currentTime - attempt.timestamp < config.windowTime then
                table.insert(newAttempts, attempt)
            end
        end
        
        if #newAttempts > 0 then
            attempts[ip] = {
                attempts = newAttempts,
                lastAttempt = data.lastAttempt
            }
        else
            attempts[ip] = nil
        end
    end
    
    -- Nettoyer les IPs bloquées expirées
    for ip, blockInfo in pairs(blockedIPs) do
        if currentTime - blockInfo.timestamp >= config.blockDuration then
            blockedIPs[ip] = nil
            print("[RATE LIMITER] IP débloquée:", ip)
        end
    end
    
    lastCleanup = currentTime
end

-- Vérifier si une IP est bloquée
function RateLimiter.isBlocked(ip)
    if not ip then return false end
    
    -- Nettoyage périodique
    if os.time() - lastCleanup > config.cleanupInterval then
        RateLimiter.cleanup()
    end
    
    local blockInfo = blockedIPs[ip]
    if not blockInfo then return false end
    
    -- Vérifier si le blocage est encore actif
    if os.time() - blockInfo.timestamp >= config.blockDuration then
        blockedIPs[ip] = nil
        return false
    end
    
    return true, blockInfo
end

-- Enregistrer une tentative
function RateLimiter.recordAttempt(ip, action, success)
    if not ip then return end
    
    local currentTime = os.time()
    action = action or "auth"
    
    -- Initialiser les données pour cette IP si nécessaire
    if not attempts[ip] then
        attempts[ip] = {
            attempts = {},
            lastAttempt = currentTime
        }
    end
    
    -- Ajouter la tentative
    table.insert(attempts[ip].attempts, {
        timestamp = currentTime,
        action = action,
        success = success
    })
    
    attempts[ip].lastAttempt = currentTime
    
    -- Si échec, vérifier si on doit bloquer
    if not success then
        local recentFailures = RateLimiter.getRecentFailures(ip)
        
        if recentFailures >= config.maxAttempts then
            RateLimiter.blockIP(ip, "Trop de tentatives échouées")
        end
    end
end

-- Obtenir le nombre d'échecs récents
function RateLimiter.getRecentFailures(ip)
    if not ip or not attempts[ip] then return 0 end
    
    local currentTime = os.time()
    local failures = 0
    
    for _, attempt in ipairs(attempts[ip].attempts) do
        if currentTime - attempt.timestamp < config.windowTime and not attempt.success then
            failures = failures + 1
        end
    end
    
    return failures
end

-- Bloquer une IP
function RateLimiter.blockIP(ip, reason)
    if not ip then return end
    
    blockedIPs[ip] = {
        timestamp = os.time(),
        reason = reason or "Comportement suspect"
    }
    
    print("[RATE LIMITER] IP bloquée:", ip, "- Raison:", reason)
end

-- Débloquer une IP manuellement
function RateLimiter.unblockIP(ip)
    if not ip then return false end
    
    if blockedIPs[ip] then
        blockedIPs[ip] = nil
        print("[RATE LIMITER] IP débloquée manuellement:", ip)
        return true
    end
    
    return false
end

-- Obtenir les statistiques d'une IP
function RateLimiter.getIPStats(ip)
    if not ip then return nil end
    
    local stats = {
        ip = ip,
        totalAttempts = 0,
        recentFailures = 0,
        isBlocked = false,
        blockInfo = nil,
        lastAttempt = nil
    }
    
    -- Vérifier si bloquée
    local blocked, blockInfo = RateLimiter.isBlocked(ip)
    stats.isBlocked = blocked
    stats.blockInfo = blockInfo
    
    -- Compter les tentatives
    if attempts[ip] then
        stats.totalAttempts = #attempts[ip].attempts
        stats.recentFailures = RateLimiter.getRecentFailures(ip)
        stats.lastAttempt = attempts[ip].lastAttempt
    end
    
    return stats
end

-- Obtenir toutes les statistiques
function RateLimiter.getAllStats()
    local stats = {
        totalIPs = 0,
        blockedIPs = 0,
        activeAttempts = 0,
        config = config
    }
    
    -- Compter les IPs avec tentatives
    for ip, data in pairs(attempts) do
        stats.totalIPs = stats.totalIPs + 1
        stats.activeAttempts = stats.activeAttempts + #data.attempts
    end
    
    -- Compter les IPs bloquées
    for ip, blockInfo in pairs(blockedIPs) do
        stats.blockedIPs = stats.blockedIPs + 1
    end
    
    return stats
end

-- Middleware pour vérifier les tentatives
function RateLimiter.checkRequest(ip, action)
    if not ip then
        return false, "Adresse IP manquante"
    end
    
    -- Vérifier si l'IP est bloquée
    local blocked, blockInfo = RateLimiter.isBlocked(ip)
    if blocked then
        local remainingTime = config.blockDuration - (os.time() - blockInfo.timestamp)
        return false, string.format("IP bloquée. Réessayez dans %d secondes", remainingTime)
    end
    
    -- Vérifier le nombre de tentatives récentes
    local recentFailures = RateLimiter.getRecentFailures(ip)
    if recentFailures >= config.maxAttempts - 1 then
        return false, "Trop de tentatives récentes. Ralentissez."
    end
    
    return true, "OK"
end

-- Configurer le rate limiter
function RateLimiter.configure(newConfig)
    if not newConfig or type(newConfig) ~= "table" then
        return false, "Configuration invalide"
    end
    
    for key, value in pairs(newConfig) do
        if config[key] ~= nil and type(value) == type(config[key]) then
            config[key] = value
        end
    end
    
    return true, "Configuration mise à jour"
end

-- Obtenir la configuration actuelle
function RateLimiter.getConfig()
    return config
end

-- Réinitialiser toutes les données
function RateLimiter.reset()
    attempts = {}
    blockedIPs = {}
    lastCleanup = os.time()
    print("[RATE LIMITER] Données réinitialisées")
end

-- Fonction d'aide pour obtenir l'IP du client (simplifié)
function RateLimiter.getClientIP(clientid)
    -- Dans un vrai projet, extraire l'IP réelle du client
    -- Pour le moment, on utilise le clientid comme identificateur
    return "client_" .. tostring(clientid)
end

return RateLimiter 
