_G.baseDir      = (...):match("(.-)[^%.]+$")
_G.libDir       = _G.baseDir .. "lib."
_G.engineDir    = _G.libDir .. "engine."

_G.gameDir      = _G.baseDir .. "game."
_G.componentsDir = _G.gameDir .. "components."
_G.entitiesDir  = _G.gameDir .. "entities."
_G.systemsDir   = _G.gameDir .. "systems."
_G.worldsDir   = _G.gameDir .. "worlds."

local redis = require(_G.libDir .. "redis")
-- print(redis)
_G.RedisClient = redis.connect('127.0.0.1', 6379)

-- Nouveau serializer pour la compatibilité avec le client
local Serializer = require(_G.libDir .. "serializer")
-- local pingresponse = _G.RedisClient:ping()
-- if not pingresponse then
--     love.event.quit()
-- end
-- -- local response = _G.RedisClient:hset('worlds:test', 14, "{\"colour\":\"blue\"}")
-- -- print(response)
-- local ares = _G.RedisClient:hget('users', 14)
-- print(ares)

local random = math.random
_G.uuid = function ()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and love.math.random(0, 0xf) or love.math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

_G.Server = {
    Clients = {},
    getClientByTcp = function (self, clientid)
        local uid = nil
        for k, v in pairs(self.Clients) do
            if v.tcp == clientid then
                uid = k
            end
        end
        return uid
    end,
    getClientByUdp = function (self, clientid)
        local uid = nil
        for k, v in pairs(self.Clients) do
            if v.udp == clientid then
                uid = k
            end
        end
        return uid
    end,
    Tcp = require(_G.libDir .. "tcp_server"):new(),
    Udp = require(_G.libDir .. "udp_server"):new()
}
local JSON = require(_G.libDir .. "json")

_G.bitser = require(_G.libDir .. "bitser")
_G.DB = {}

local entities, entitiesError = love.filesystem.read("game/entities/entities.json")
_G.DB.Entities = JSON:decode(entities)

local handshake = "00000"
_G.RealmWorld = require(_G.worldsDir .. "world-realm"):new()
local PlayerEntity = require(_G.entitiesDir .. "entity-player")
local ProjectileEntity = require(_G.entitiesDir .. "entity-projectile")
local GoldMineEntity = require(_G.entitiesDir .. "entity-goldmine")

_G.Server.Tcp.handshake = handshake
_G.Server.Udp.handshake = handshake

function love.load(arg)
    _G.Server.Tcp:listen(8082)
    _G.Server.Udp:listen(8082)
    for k, v in pairs(arg) do
        print(k, v)
        if k == 1 then
        end
    end
end

_G.Server.Udp.callbacks.recv = function (data, clientid)
    -- print("[".. tostring(clientid) .. "]: " .. packet.id)
    local packet = _G.bitser.loads(data)

    if packet.id == "connection" then
        local playerId = packet.data.email
        if type(_G.Server.Clients[playerId]) ~= "table" then
            _G.Server.Clients[playerId] = {}
        end
        _G.Server.Clients[playerId].udp = clientid
        _G.Server.Clients[playerId].lastSeen = love.timer.getTime()
        
        print("[UDP][".. playerId .."]: connected")
    elseif packet.id == "disconnection" then
        local playerId = packet.data.email
        if _G.Server.Clients[playerId] then
            _G.Server.Clients[playerId].udp = nil
            print("[UDP][".. playerId .."]: disconnected")
        else
            print("[UDP] Tentative de déconnexion pour un client inexistant:", playerId)
        end
    elseif packet.id == "player_move" then
        local uid = _G.Server:getClientByUdp(clientid)
        
        -- Mettre à jour lastSeen pour maintenir la connexion active
        if uid and _G.Server.Clients[uid] then
            _G.Server.Clients[uid].lastSeen = love.timer.getTime()
        end
        
        local entity = _G.RealmWorld:getEntityById(uid)
        if entity then
            local tranformComponent = entity:getComponent("Position")
            if packet.cmd == "up" then
                tranformComponent.position.y = tranformComponent.position.y - 2
            elseif packet.cmd == "down" then
                tranformComponent.position.y = tranformComponent.position.y + 2
            elseif packet.cmd == "left" then
                tranformComponent.position.x = tranformComponent.position.x - 2
            elseif packet.cmd == "right" then
                tranformComponent.position.x = tranformComponent.position.x + 2
            end
        end    
    elseif packet.id == "player_shoot" then
        local uid = _G.Server:getClientByUdp(clientid)
        
        -- Mettre à jour lastSeen pour maintenir la connexion active
        if uid and _G.Server.Clients[uid] then
            _G.Server.Clients[uid].lastSeen = love.timer.getTime()
        end
        
        local entity = _G.RealmWorld:getEntityById(uid)
        if entity then
            entity:shoot()
        end
    elseif packet.id == "player_pvp" then
        local uid = _G.Server:getClientByUdp(clientid)
        
        -- Mettre à jour lastSeen pour maintenir la connexion active
        if uid and _G.Server.Clients[uid] then
            _G.Server.Clients[uid].lastSeen = love.timer.getTime()
        end
        
        local entity = _G.RealmWorld:getEntityById(uid)
        if entity then
            entity:getComponent("Player").pvp = not entity:getComponent("Player").pvp
        end
    elseif packet.id == "player_orientation" then
        local uid = _G.Server:getClientByUdp(clientid)
        
        -- Mettre à jour lastSeen pour maintenir la connexion active
        if uid and _G.Server.Clients[uid] then
            _G.Server.Clients[uid].lastSeen = love.timer.getTime()
        end
        
        local entity = _G.RealmWorld:getEntityById(uid)
        local m = packet.data
        if entity then
            local position = entity:getComponent("Position").position
            local dimension = entity:getComponent("Dimension")
            local orientation = entity:getComponent("Orientation").orientation
            entity:getComponent("Orientation").orientation = math.atan2(m.y - position.y, m.x - position.x + dimension.width / 2)
        end
    elseif packet.id == "player_shield" then
        local uid = _G.Server:getClientByUdp(clientid)
        
        -- Mettre à jour lastSeen pour maintenir la connexion active
        if uid and _G.Server.Clients[uid] then
            _G.Server.Clients[uid].lastSeen = love.timer.getTime()
        end
        
        local entity = _G.RealmWorld:getEntityById(uid)
        if entity then
            local shield = entity:getComponent("Shield")
            if shield then
                shield.activated = packet.data
            end
        end
    elseif packet.id == "player_mine" then
        local uid = _G.Server:getClientByUdp(clientid)
        
        -- Mettre à jour lastSeen pour maintenir la connexion active
        if uid and _G.Server.Clients[uid] then
            _G.Server.Clients[uid].lastSeen = love.timer.getTime()
        end
        
        if uid and packet.data and packet.data.mineId then
            -- Gérer la demande de récolte
            local result = _G.RealmWorld:handleMiningRequest(uid, packet.data.mineId)
            
            -- Envoyer le résultat au joueur via TCP pour garantir la réception
            if _G.Server.Clients[uid] and _G.Server.Clients[uid].tcp then
                _G.Server.Tcp:send(_G.bitser.dumps({
                    id = "mining_result",
                    data = result
                }), _G.Server.Clients[uid].tcp)
            end
            
            -- Log pour debug
            if result.success then
                print("[MINING] Joueur", uid, "a récolté", result.goldHarvested, "or de la mine", packet.data.mineId)
            else
                print("[MINING] Échec récolte pour joueur", uid, ":", result.reason)
            end
        end
    end
end

_G.Server.Udp.callbacks.connect = function (clientid)
    print("[UDP][".. tostring(clientid) .. "]: connected")
    _G.Server.Udp:send(_G.bitser.dumps({
        id = "request_player",
     }), clientid)
end

-- Fonction utilitaire pour nettoyer un joueur déconnecté
_G.cleanupDisconnectedPlayer = function(playerId, reason)
    reason = reason or "unknown"
    print("[CLEANUP] Nettoyage du joueur", playerId, "- Raison:", reason)
    
    -- Supprimer l'entité du monde
    local entity = _G.RealmWorld:getEntityById(playerId)
    if entity then
        _G.RealmWorld:removeEntityById(playerId)
        print("[CLEANUP] Entité joueur", playerId, "supprimée du monde")
    end
    
    -- Nettoyer les données client
    if _G.Server.Clients[playerId] then
        _G.Server.Clients[playerId] = nil
        print("[CLEANUP] Données client", playerId, "nettoyées")
    end
    
    -- Optionnel : sauvegarder le joueur dans Redis avant suppression
    -- TODO: Implémenter la sauvegarde si nécessaire
end

-- Fonction pour trouver un joueur par client TCP
_G.findPlayerByTcpClient = function(clientid)
    for playerId, clientData in pairs(_G.Server.Clients) do
        if clientData.tcp == clientid then
            return playerId
        end
    end
    return nil
end

-- Fonction pour trouver un joueur par client UDP
_G.findPlayerByUdpClient = function(clientid)
    for playerId, clientData in pairs(_G.Server.Clients) do
        if clientData.udp == clientid then
            return playerId
        end
    end
    return nil
end

_G.Server.Udp.callbacks.disconnect = function (clientid)
    print("[UDP][".. tostring(clientid) .. "]: disconnected")
    
    -- Trouver le joueur associé à ce client UDP
    local playerId = _G.findPlayerByUdpClient(clientid)
    if playerId then
        -- Marquer UDP comme déconnecté
        if _G.Server.Clients[playerId] then
            _G.Server.Clients[playerId].udp = nil
            print("[UDP] Joueur", playerId, "UDP déconnecté")
            
            -- Si TCP est aussi déconnecté, nettoyer complètement
            if not _G.Server.Clients[playerId].tcp then
                _G.cleanupDisconnectedPlayer(playerId, "UDP+TCP disconnect")
            end
        end
    end
end

_G.Server.Tcp.callbacks.recv = function (data, clientid)
    local packet = _G.bitser.loads(data)
    print("[TCP] Message reçu:", packet.id, "de client", clientid)
    
    if packet.id == "connection" then
        local playerId = packet.data.email
        print("[TCP] Tentative de connexion du joueur:", playerId)
        
        -- Nettoyer toute entité existante pour éviter les doublons
        local existingEntity = _G.RealmWorld:getEntityById(playerId)
        if existingEntity then
            print("[TCP] Entité existante trouvée pour", playerId, "- Suppression avant reconnexion")
            _G.RealmWorld:removeEntityById(playerId)
        end
        
        -- Initialiser/mettre à jour les données client
        if type(_G.Server.Clients[playerId]) ~= "table" then
            _G.Server.Clients[playerId] = {}
        end
        _G.Server.Clients[playerId].tcp = clientid
        _G.Server.Clients[playerId].lastSeen = love.timer.getTime()
        
        print("[TCP] Joueur connecté:", playerId)
        print("[TCP] Nom du personnage:", packet.data.characterName)
        
        -- Récupérer les données du personnage depuis Redis
        local characterData = _G.RedisClient:hget("character:"..packet.data.characterName, "data")
        print("[TCP] Données Redis:", characterData and "trouvées" or "non trouvées")
        
        -- Créer l'entité joueur (toujours une nouvelle entité après nettoyage)
        local playerData = {
            position = { x = 100, y = 100 },
            orientation = 0,
            dimension = { width = 32, height = 32 },
            hand = nil,
            viewDistance = 500,
            intelligence = 10,
            force = 10,
            speed = 3,
            agility = 10,
            life = 10,
            fame = 0,
            shield = 100,
            wallet = 100,
            clan = { name = "test" },
            quest = nil,
            name = packet.data.characterName,
            texture = {
                size = 16,
                index = 1,
                name = "player"
            }
        }
        
        -- Appliquer les données sauvegardées si disponibles
        if characterData then
            local characterDataDecoded = JSON:decode(characterData)
            if characterDataDecoded then
                playerData.force = characterDataDecoded.force or playerData.force
                playerData.speed = characterDataDecoded.speed or playerData.speed
                playerData.agility = characterDataDecoded.agility or playerData.agility
                playerData.life = characterDataDecoded.life or playerData.life
                playerData.clan = { name = characterDataDecoded.clan or "test" }
                playerData.name = characterDataDecoded.name or playerData.name
                print("[TCP] Données personnage appliquées depuis Redis")
            end
        end
        
        -- Créer et ajouter l'entité
        _G.RealmWorld:addEntity(PlayerEntity:new(playerId, playerData))
        print("[TCP] Nouvelle entité créée pour", playerId)
        _G.Server.Tcp:send(_G.bitser.dumps({
           id = "world_load",
           world = _G.RealmWorld:toNbt()
        }), clientid)
    elseif packet.id == "disconnection" then
        -- TODO: Delete token in redis
        if _G.Server.Clients[packet.data.email] then
            _G.Server.Clients[packet.data.email].tcp = nil
            print("[TCP][".. packet.data.email .."]: disconnected")
        else
            print("[TCP] Tentative de déconnexion pour un client inexistant:", packet.data.email)
        end
    elseif packet.id == "request_player_entity" then
        local clans = { "alliance", "horde", "steampunk" }
        for k, v in pairs(_G.Server.Clients) do
            if v.tcp == clientid then
                local entity = RealmWorld:getEntityById(k)
                if not entity then
                _G.RealmWorld:addEntity(PlayerEntity:new(k, {
                    position = { x = 100, y = 100 },
                    orientation = 0,
                    dimension = { width = 32, height = 32 },
                    hand = nil,
                    viewDistance = 500,
                    intelligence = 10,
                    force = 10,
                    speed = 50,
                    agility = 10,
                    life = 100,
                    fame = 0,
                    shield = 100,
                    wallet = 100,
                    clan = { name = clans[love.math.random(1, #clans)], fame = 0 },
                    quest = nil,
                    name = "Vincent"
                }))
                end
            end 
        end
    elseif packet.id == "join_world" then
        local serverWorld = _G.RedisClient:hgetall("worlds:".. packet.data.name)
        -- if #serverWorld < 1 then
        --     _G.Server.Tcp:send(Serializer.serializePacket({
        --         id = "join_world",
        --         status = 404
        --     }))
        -- else
            _G.Server.Tcp:send(_G.bitser.dumps({
                id = "join_world",
                status = 200,
                server = {
                    ip = serverWorld.ip,
                    port = serverWorld.port
                }
            }), clientid)
        -- end
        for k, v in pairs(serverWorld) do
            print(k, v)
        end
    end
end

_G.Server.Tcp.callbacks.connect = function (clientid )
    print("[TCP][".. tostring(clientid) .. "]: connected")
end

_G.Server.Tcp.callbacks.disconnect = function (clientid)
    print("[TCP][".. tostring(clientid) .. "]: disconnected")
    
    -- Trouver le joueur associé à ce client TCP
    local playerId = _G.findPlayerByTcpClient(clientid)
    if playerId then
        -- Marquer TCP comme déconnecté
        if _G.Server.Clients[playerId] then
            _G.Server.Clients[playerId].tcp = nil
            print("[TCP] Joueur", playerId, "TCP déconnecté")
            
            -- Si UDP est aussi déconnecté, nettoyer complètement
            if not _G.Server.Clients[playerId].udp then
                _G.cleanupDisconnectedPlayer(playerId, "TCP+UDP disconnect")
            end
        end
    else
        -- Nettoyage générique si le joueur n'est pas trouvé
        print("[TCP] Client inconnu déconnecté, nettoyage générique")
    end
end

function love.update (dt)
    _G.Server.Tcp:update(dt)
    _G.Server.Udp:update(dt)
    _G.RealmWorld:update(dt)
end

function love.quit()
    _G.Server.Tcp:close()
    _G.Server.Udp:close()
end

-- Fonctions globales pour contrôler le debug
function setInteractionDebug(enabled)
    if _G.RealmWorld then
        _G.RealmWorld:setInteractionDebug(enabled)
        print("Debug du système d'interaction:", enabled and "ACTIVÉ" or "DÉSACTIVÉ")
    else
        print("Erreur: Le monde n'est pas encore initialisé")
    end
end

function toggleInteractionDebug()
    if _G.RealmWorld then
        local newState = _G.RealmWorld:toggleInteractionDebug()
        print("Debug du système d'interaction basculé:", newState and "ACTIVÉ" or "DÉSACTIVÉ")
        return newState
    else
        print("Erreur: Le monde n'est pas encore initialisé")
        return false
    end
end

-- Fonction d'aide pour afficher les commandes de debug disponibles
function debugHelp()
    print("=== COMMANDES DE DEBUG DISPONIBLES ===")
    print("setInteractionDebug(true/false)     - Active/désactive les logs du système d'interaction")
    print("toggleInteractionDebug()            - Bascule l'état du debug d'interaction")
    print("setConnectionCleanupDebug(true/false) - Active/désactive les logs du système de nettoyage")
    print("forceConnectionCleanup()            - Force un nettoyage des connexions")
    print("getConnectionStats()                - Affiche les statistiques des connexions")
    print("debugHelp()                         - Affiche cette aide")
    print("=====================================")
end

-- Fonctions globales pour contrôler le système de nettoyage des connexions
function setConnectionCleanupDebug(enabled)
    if _G.RealmWorld then
        _G.RealmWorld:setConnectionCleanupDebug(enabled)
        print("Debug du système de nettoyage des connexions:", enabled and "ACTIVÉ" or "DÉSACTIVÉ")
    else
        print("Erreur: Le monde n'est pas encore initialisé")
    end
end

function forceConnectionCleanup()
    if _G.RealmWorld then
        _G.RealmWorld:forceConnectionCleanup()
    else
        print("Erreur: Le monde n'est pas encore initialisé")
    end
end

function getConnectionStats()
    if _G.RealmWorld then
        local stats = _G.RealmWorld:getConnectionStats()
        print("=== STATISTIQUES DES CONNEXIONS ===")
        print("Clients totaux:", stats.totalClients)
        print("Connexions TCP:", stats.tcpConnections)
        print("Connexions UDP:", stats.udpConnections)
        print("Connexions complètes (TCP+UDP):", stats.completeConnections)
        print("Connexions partielles:", stats.partialConnections)
        print("Connexions en timeout:", stats.timeouts)
        print("=====================================")
        return stats
    else
        print("Erreur: Le monde n'est pas encore initialisé")
        return {}
    end
end
