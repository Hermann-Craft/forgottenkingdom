local GameServersScreen = require(_G.libDir .. "middleclass")("GameServersScreen", _G.xle.Scene)
local ButtonElement = require(_G.engineDir .. "builtin.gameobjects.button")
local World = require(_G.engineDir .. "world")
local http = require("socket.http")
local json = require(_G.libDir .. "json")

function GameServersScreen:initialize (name, active )
    _G.xle.Scene.initialize(self, name, active)
end

function GameServersScreen:init()
    _G.xle.Scene.init(self)
    love.window.setTitle(self.name)

    self.nodes = {
        refresh = ButtonElement:new("Refresh", 10, 150),
    }

    self.serverList = {}

    self.position = {
        x = 0,
        y = 0
    }

    self.world = World:new(400, 400)
end

function GameServersScreen:update(...)
    for k in pairs(self.nodes) do
        if self.nodes[k].update ~= nil then
            self.nodes[k]:update(...)
        end
    end

end

function GameServersScreen:draw(...)
    for k in pairs(self.nodes) do
        if self.nodes[k].draw ~= nil then
            self.nodes[k]:draw(...)
        end
    end

    self.world:draw()
end

function GameServersScreen:mousepressed(...)
    for k in pairs(self.nodes) do
        if self.nodes[k].mousepressed ~= nil then
            self.nodes[k]:mousepressed(...)
        end
    end

    -- mx, my = self.world2.camera:mousePosition()
    -- for x=0, self.world.width / self.tools.gridSize.width do
    --     for y=0, self.world.height / self.tools.gridSize.height do
    --         if mx > x * self.tools.gridSize.width and mx < (x * self.tools.gridSize.width) + self.tools.gridSize.width and my > y * self.tools.gridSize.height and my < (y * self.tools.gridSize.height) + self.tools.gridSize.height then
    --             -- table.insert(self.world.entities, #self.world.entities + 1, )
                -- self.world2:addEntity({
                --     id = "test",
                --     components = {
                --         Position = {
                --             position = {
                --                 x = 0,
                --                 y = 0
                --             }
                --         },
                --         Dimension= {
                --             width = 16,
                --             height = 16
                --         },
                --     }
                -- })
    --             love.graphics.rectangle("fill", x * self.tools.gridSize.width, y * self.tools.gridSize.height, self.tools.gridSize.width, self.tools.gridSize.height )
    --         end
    --     end
    -- end
end
function GameServersScreen:mousereleased(...)
    for k in pairs(self.nodes) do
        if self.nodes[k].mousereleased ~= nil then
            self.nodes[k]:mousereleased(...)
        end
    end
    self.world:mousereleased(...)
end

return GameServersScreen;