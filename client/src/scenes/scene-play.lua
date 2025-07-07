local PlayScreen = require(_G.libDir .. "middleclass")("PlayScreen", _G.xle.Scene)
local ButtonElement = require(_G.engineDir .. "builtin.gameobjects.button")

function PlayScreen:initialize (name, active )
    _G.xle.Scene.initialize(self, name, active)
end

function PlayScreen:init()
    _G.xle.Scene.init(self)
    love.window.setTitle("Forgotten Kingdom - Jeu")

    self.nodes = {
    }
    
    -- Gestionnaire d'interface utilisateur pour le mining
    self.uiManager = require(_G.engineDir .. "ui_manager"):new()
    
    print("[PLAY] === INITIALISATION SCÈNE DE JEU ===")
    print("[PLAY] _G.worldServer:", _G.worldServer and "existe" or "nil")
    print("[PLAY] _G.user:", _G.user and "existe" or "nil")
    if _G.user then
        print("[PLAY] _G.user.email:", _G.user.email or "nil")
        print("[PLAY] _G.user.selectedCharacter:", _G.user.selectedCharacter or "nil")
        print("[PLAY] _G.user.token:", _G.user.token and "existe" or "nil")
    end
    
    -- Vérifier que nous avons bien un worldServer configuré
    if not _G.worldServer then
        print("[PLAY] ❌ Erreur: worldServer non configuré, retour à la sélection")
        _G.xle.Scene.goToScene("scene-character-select")
        return
    end
    
    -- Vérifier que nous avons un personnage sélectionné
    if not _G.user or not _G.user.selectedCharacter then
        print("[PLAY] ❌ Erreur: aucun personnage sélectionné, retour à la sélection")
        _G.xle.Scene.goToScene("scene-character-select")
        return
    end
    
    print("[PLAY] ✅ Initialisation du jeu pour:", _G.user.selectedCharacter)
    
    -- Plus besoin de gérer les boutons de personnage car le personnage est déjà sélectionné
    self.charactersButtons = {}
end

function PlayScreen:update(dt, ...)
    -- Mettre à jour l'UI Manager et l'assigner au WorldServer si nécessaire
    if self.uiManager then
        self.uiManager:update(dt)
        
        -- Assigner l'UIManager au WorldServer s'il existe et n'est pas encore assigné
        if _G.worldServer and not _G.worldServer.uiManager then
            _G.worldServer:setUIManager(self.uiManager)
        end
    end

    -- Mettre à jour le WorldServer si il existe
    if _G.worldServer then
        _G.worldServer:update(dt)
    end

    for k in pairs(self.charactersButtons) do
        if self.charactersButtons[k].update ~= nil then
            self.charactersButtons[k]:update(dt, ...)
        end
    end

    for k in pairs(self.nodes) do
        if self.nodes[k].update ~= nil then
            self.nodes[k]:update(dt, ...)
        end
    end
end

function PlayScreen:draw(...)
    if _G.worldServer ~= nil then
        _G.worldServer:draw(...)
        
        -- Affichage de l'interface de mining avec UIManager
        if self.uiManager then
            local miningInfo = _G.worldServer:getMiningInfo()
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            
            -- Mettre à jour les indicateurs de proximité dans le monde
            if _G.worldServer.world then
                _G.worldServer.world:updateNearbyMineIndicators(miningInfo.nearbyMines)
            end
            
            self.uiManager:drawMiningInterface(miningInfo, screenWidth, screenHeight)
        end
        
        -- Remettre la couleur par défaut
        love.graphics.setColor(1, 1, 1, 1)
    else
        -- Afficher un message d'erreur si le worldServer n'est pas disponible
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.printf("Erreur: Connexion au serveur de jeu perdue", 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.printf("Appuyez sur Échap pour retourner à la sélection de personnage", 0, love.graphics.getHeight() / 2 + 30, love.graphics.getWidth(), "center")
        love.graphics.setColor(1, 1, 1, 1)
    end

    for k in pairs(self.charactersButtons) do
        if self.charactersButtons[k].draw ~= nil then
            self.charactersButtons[k]:draw(...)
        end
    end

    for k in pairs(self.nodes) do
        if self.nodes[k].draw ~= nil then
            self.nodes[k]:draw(...)
        end
    end
end

function PlayScreen:mousepressed(...)
    for k in pairs(self.charactersButtons) do
        if self.charactersButtons[k].mousepressed ~= nil then
            self.charactersButtons[k]:mousepressed(...)
        end
    end

    for k in pairs(self.nodes) do
        if self.nodes[k].mousepressed ~= nil then
            self.nodes[k]:mousepressed(...)
        end
    end
end

function PlayScreen:mousereleased(...)
    for k in pairs(self.charactersButtons) do
        if self.charactersButtons[k].mousereleased ~= nil then
            self.charactersButtons[k]:mousereleased(...)
        end
    end

    for k in pairs(self.nodes) do
        if self.nodes[k].mousereleased ~= nil then
            self.nodes[k]:mousereleased(...)
        end
    end
end

function PlayScreen:keyreleased(key)
    -- Touche d'échappement pour retourner à la sélection de personnage
    if key == "escape" then
        print("[PLAY] Retour à la sélection de personnage")
        _G.xle.Scene.goToScene("scene-character-select")
        return
    end
    
    if _G.worldServer ~= nil then
        if key == "p" then
            _G.worldServer.udp:send(_G.bitser.dumps({
                id = "player_pvp"
            }))
        end
        if key == "lshift" then
            _G.worldServer.udp:send(_G.bitser.dumps({
                id = "player_shield",
                data = false
            }))
        end
        if key == "e" then
            -- Tentative de mining avec feedback UI
            if self.uiManager then
                self.uiManager:onMiningAttempt()
            end
            
            local success = _G.worldServer:tryMining()
            if not success and self.uiManager then
                self.uiManager:onMiningError("Aucune mine disponible pour miner")
            end
        end
    end
end

function PlayScreen:keypressed(key)
    if _G.worldServer ~= nil then
        if key == "lshift" then
            _G.worldServer.udp:send(_G.bitser.dumps({
                id = "player_shield",
                data = true
            }))
        end
    end
end

return PlayScreen;
