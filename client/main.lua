require("conf")

-- Configuration des chemins globaux
_G.baseDir      = (...):match("(.-)[^%.]+$")
_G.libDir       = _G.baseDir .. "lib."
_G.srcDir       = _G.baseDir .. "src."
_G.engineDir    = _G.libDir .. "engine."

-- Utils
_G.bitser = require(_G.libDir .. "bitser")

-- Server configuration (will be managed by AuthManager)
_G.user = {
    email = nil,
    token = nil,
    characters = {},
    selectedCharacter = nil
}

_G.masterServer = nil
_G.worldServer = nil

-- Instance globale d'AuthManager pour partager entre les scènes
_G.authManager = nil

-- Ajouter un système de debug global
_G.DEBUG_MODE = true
_G.DEBUG_LOGS = {}
_G.DEBUG_VISIBLE = false

-- Fonction pour ajouter des logs de debug
function _G.addDebugLog(message)
    if _G.DEBUG_MODE then
        table.insert(_G.DEBUG_LOGS, {
            time = love.timer.getTime(),
            message = message
        })
        
        -- Garder seulement les 50 derniers logs
        if #_G.DEBUG_LOGS > 50 then
            table.remove(_G.DEBUG_LOGS, 1)
        end
        
        print("[DEBUG]", message)
    end
end

-- Fonction pour dessiner l'overlay de debug
function _G.drawDebugOverlay()
    if not _G.DEBUG_VISIBLE then return end
    
    local width, height = love.graphics.getDimensions()
    local overlayWidth = 600
    local overlayHeight = 400
    local x = width - overlayWidth - 10
    local y = 10
    
    -- Fond semi-transparent
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, overlayWidth, overlayHeight)
    
    -- Bordure
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", x, y, overlayWidth, overlayHeight)
    
    -- Titre
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("DEBUG OVERLAY (F12 pour masquer)", x + 10, y + 10)
    
    -- État d'authentification
    love.graphics.setColor(1, 1, 1, 1)
    local authInfo = ""
    if _G.authManager then
        authInfo = string.format("Auth: %s | Email: %s | Token: %s",
            _G.authManager.isAuthenticated and "✓" or "✗",
            _G.authManager.currentUser.email or "nil",
            _G.authManager.currentUser.token and "existe" or "nil"
        )
    else
        authInfo = "AuthManager: non initialisé"
    end
    love.graphics.print(authInfo, x + 10, y + 30)
    
    -- État _G.user
    local userInfo = ""
    if _G.user then
        userInfo = string.format("_G.user - Email: %s | Token: %s",
            _G.user.email or "nil",
            _G.user.token and "existe" or "nil"
        )
    else
        userInfo = "_G.user: nil"
    end
    love.graphics.print(userInfo, x + 10, y + 50)
    
    -- Logs récents
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.print("Logs récents:", x + 10, y + 80)
    
    local logY = y + 100
    for i = math.max(1, #_G.DEBUG_LOGS - 15), #_G.DEBUG_LOGS do
        if _G.DEBUG_LOGS[i] then
            local logText = string.format("[%.1f] %s", 
                _G.DEBUG_LOGS[i].time, 
                _G.DEBUG_LOGS[i].message
            )
            love.graphics.print(logText, x + 10, logY)
            logY = logY + 18
        end
    end
    
    -- Raccourcis
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("F1: Debug Token | F2: Force Auth | F3: Test Create", x + 10, overlayHeight - 30)
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Fonctions de debug
function _G.debugTokenState()
    _G.addDebugLog("=== DEBUG TOKEN STATE ===")
    
    if _G.user then
        _G.addDebugLog("✓ _G.user existe")
        _G.addDebugLog("Email: " .. (_G.user.email or "nil"))
        _G.addDebugLog("Token: " .. (_G.user.token and "existe" or "nil"))
        if _G.user.token then
            _G.addDebugLog("Token début: " .. _G.user.token .. "...")
        end
    else
        _G.addDebugLog("❌ _G.user n'existe pas")
    end
    
    if _G.authManager then
        _G.addDebugLog("✓ _G.authManager existe")
        _G.addDebugLog("isAuthenticated: " .. tostring(_G.authManager.isAuthenticated))
        _G.addDebugLog("currentUser.email: " .. (_G.authManager.currentUser.email or "nil"))
        _G.addDebugLog("currentUser.token: " .. (_G.authManager.currentUser.token and "existe" or "nil"))
        if _G.authManager.currentUser.token then
            _G.addDebugLog("Token début: " .. _G.authManager.currentUser.token .. "...")
        end
    else
        _G.addDebugLog("❌ _G.authManager n'existe pas")
    end
end

function _G.forceAuthState()
    _G.addDebugLog("=== FORCE AUTH STATE ===")
    
    if _G.authManager then
        _G.authManager.isAuthenticated = true
        
        if not _G.authManager.currentUser.email then
            _G.authManager.currentUser.email = "test@example.com"
        end
        
        if not _G.authManager.currentUser.token then
            _G.authManager.currentUser.token = "debug_token_123456789"
        end
        
        _G.authManager:syncGlobalUser()
        _G.addDebugLog("✓ État d'authentification forcé")
    else
        _G.addDebugLog("❌ AuthManager non trouvé")
    end
end

function _G.testQuickCreate()
    _G.addDebugLog("=== TEST CREATION RAPIDE ===")
    
    if _G.authManager then
        local characterData = {
            name = "DebugChar" .. math.random(1000, 9999),
            clan = "Neutral",
            stats = {
                force = 13,
                intelligence = 13,
                speed = 13,
                agility = 13
            }
        }
        
        _G.addDebugLog("Email: " .. (_G.authManager.currentUser.email or "nil"))
        _G.addDebugLog("Token: " .. (_G.authManager.currentUser.token and "existe" or "nil"))
        _G.addDebugLog("Nom: " .. characterData.name)
        
        local success = _G.authManager:createCharacter(characterData)
        _G.addDebugLog("Résultat: " .. (success and "Succès" or "Échec"))
    else
        _G.addDebugLog("❌ AuthManager non disponible")
    end
end

-- XLE configuration
local scenes = require(_G.srcDir .. "scenes.scenes")
_G.xle = require(_G.engineDir .. "xle")

function love.load()
    _G.addDebugLog("Love2D démarré en mode debug")
    
    _G.xleInstance = _G.xle.Init:new("forgottenkingdom", scenes)
    
    _G.xleInstance:addCallback("updateServer", "update", function (dt)
        if _G.masterServer ~= nil then
            _G.masterServer:update(dt)
        end
    
        if _G.worldServer ~= nil then
            _G.worldServer:update(dt)
        end
    end)
    
    _G.xleInstance:addCallback("exitServer", "quit", function ()
        print("quit")
        if _G.masterServer ~= nil then
            _G.masterServer:disconnect()
        end
    
        if _G.worldServer ~= nil then
            _G.worldServer:disconnect()
        end
    end)
    
    _G.addDebugLog("Scenes initialisées")
end

function love.update(dt)
    -- Update standard XLE
    if _G.xleInstance then
        _G.xleInstance:update(dt)
    end
end

function love.draw()
    -- Draw standard XLE
    if _G.xleInstance then
        _G.xleInstance:draw()
    end
    
    -- Overlay de debug
    _G.drawDebugOverlay()
end

function love.keypressed(key)
    -- Transmettre à XLE
    if _G.xleInstance then
        _G.xleInstance:keypressed(key)
    end
    
    -- Raccourcis de debug
    if key == "f12" then
        _G.DEBUG_VISIBLE = not _G.DEBUG_VISIBLE
        _G.addDebugLog("Debug overlay: " .. (_G.DEBUG_VISIBLE and "activé" or "désactivé"))
    elseif key == "f1" then
        _G.debugTokenState()
    elseif key == "f2" then
        _G.forceAuthState()
    elseif key == "f3" then
        _G.testQuickCreate()
    end
end

function love.keyreleased(key)
    if _G.xleInstance then
        _G.xleInstance:keyreleased(key)
    end
end

function love.mousepressed(x, y, button)
    if _G.xleInstance then
        _G.xleInstance:mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if _G.xleInstance then
        _G.xleInstance:mousereleased(x, y, button)
    end
end

function love.textinput(text)
    if _G.xleInstance then
        _G.xleInstance:textinput(text)
    end
end


