local GameMainMenuScreen = require(_G.libDir .. "middleclass")("GameMainMenuScreen", _G.xle.Scene)
local ButtonElement = require(_G.engineDir .. "builtin.gameobjects.button")
local LabelElement = require(_G.engineDir .. "builtin.gameobjects.label")

function GameMainMenuScreen:initialize (name, active )
    _G.xle.Scene.initialize(self, name, active)
end

function GameMainMenuScreen:init()
    _G.xle.Scene.init(self)
    love.window.setTitle(self.name)
    
    local w, h = love.graphics.getDimensions()

    self.nodes = {
        worldButton = ButtonElement:new("WorldEditor", 10, 150),
        playMultiButton = ButtonElement:new("Online", 10, 50, true),
        optionButton = ButtonElement:new("option", 10, 100),
        emailLabel = LabelElement:new(_G.user.email, w - 200, 10)
    }

    self.nodes.worldButton:addOnClickEvent("changeScreen", function ()
        _G.xle.Scene.goToScene("scene-world");
    end)


    self.nodes.playMultiButton:addOnClickEvent("changeScreen", function ()
        _G.xle.Scene.goToScene("scene-play");
    end)

    self.nodes.optionButton:addOnClickEvent("changeScreen", function ()
        _G.xle.Scene.goToScene("scene-option");
    end)

    self:initMasterServer()
end

function GameMainMenuScreen:initMasterServer()

    _G.masterServer = require(_G.libDir .. "master_client"):new()

    _G.masterServer.handshake = "00000"

    _G.masterServer:connect("127.0.0.1", 8080)

    _G.masterServer.callbacks.recv = function (data)
        local packet = _G.bitser.loads(data)
        print(packet.id)
        if packet.id == "request_identity" then
            _G.masterServer:send(_G.bitser.dumps({
                id = "connect_with_password",
                data = {
                    email = _G.user.email,
                    password = "123"
                },
            }))
        elseif packet.id == "connection" then
            print(packet.id ..":".. packet.data.type)
            if packet.data.type == "success" then
                self.nodes.playMultiButton.disabled = false
                _G.user.token = packet.data.payload.token
                worldServer = require(_G.libDir .. "engine.world_server"):new(_G.user)
            end
        elseif packet.id == "create_character" then
            if packet.data.type == "error" then
                print(packet.data.payload)
            end
        elseif packet.id == "list_character" then
            if packet.data.type == "success" then
                print(#packet.data.payload)
                for i, v in ipairs(packet.data.payload) do
                    table.insert(_G.user.characters, #_G.user.characters + 1, v)
                end
            end
            print("hello")
        elseif packet.id == "play" then
            print(packet.id .. ":".. packet.data.type)
            print("world = " .. packet.data.payload.world.name .. " {" .. packet.data.payload.world.ip .. ":" .. packet.data.payload.world.port .. "}")
            
            _G.user.selectedCharacter = packet.data.payload.characterName
            if _G.worldServer ~= nil then
                _G.worldServer:disconnect()
                _G.worldServer:connect(packet.data.payload.world.ip, packet.data.payload.world.port)
            else
                _G.worldServer = require(_G.engineDir .. "world_server"):new(packet.data.payload.characterName)
                _G.worldServer:connect(packet.data.payload.world.ip, packet.data.payload.world.port)
            end 
        end
    end
end

function GameMainMenuScreen:update(...)
    for k in pairs(self.nodes) do
        if self.nodes[k].update ~= nil then
            self.nodes[k]:update(...)
        end
    end
end

function GameMainMenuScreen:draw(...)
    for k in pairs(self.nodes) do
        if self.nodes[k].draw ~= nil then
            self.nodes[k]:draw(...)
        end
    end
end

function GameMainMenuScreen:mousepressed(...)
    for k in pairs(self.nodes) do
        if self.nodes[k].mousepressed ~= nil then
            self.nodes[k]:mousepressed(...)
        end
    end
end
function GameMainMenuScreen:mousereleased(...)
    for k in pairs(self.nodes) do
        if self.nodes[k].mousereleased ~= nil then
            self.nodes[k]:mousereleased(...)
        end
    end
end

return GameMainMenuScreen;
