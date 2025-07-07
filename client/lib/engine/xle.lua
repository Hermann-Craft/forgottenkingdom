local XLE = require(_G.libDir .. "middleclass")("God")

local Scene = require(_G.engineDir .. "scene")
local callbacks = {
    all = {
        "directorydropped",
        "displayrotated",
        "errhand",
        "errorhandler",
        "filedropped",
        "focus",
        "gamepadaxis",
        "gamepadpressed",
        "gamepadrelease",
        "joystickadded",
        "joystickaxis",
        "joystickhat",
        "joystickpresse",
        "joystickrelease",
        "joystickremove",
        "load",
        "lowmemory",
        "quit",
        "textedited",
        "textinput",
        "threaderror",
        "touchmoved",
        "touchpressed",
        "touchreleased",
        "visible",
    },
    supported = {
        "wheelmoved",
        "mousefocus",
        "mousemoved",
        "mousepressed",
        "mousereleased",
        "update",
        "conf",
        "load",
        "draw",
        "keypressed",
        "keyreleased",
        "textinput",
        "resize",
        "quit"
    }
}

XLE.static.optionsCached = {}


function XLE:initialize(gameName, scenes )
    self.game_name = gameName
    -- require and initialise
    for i, v in ipairs(scenes) do
        require(_G.srcDir .. "scenes."..v.path):new(v.name, v.index == 1 )
    end
    self.callbacks = {}
    self:load()
end

function XLE:load()
    for k, v in ipairs(Scene.scenesInstances) do
        if v.active then
            v:init()
        end
    end
    local w, h = love.window.getMode()
    self.old = {
        scene = {
            w = w,
            h = h
        }
    }
    for _, v in ipairs(callbacks.supported) do
        love[v] = function (...)
            if v == "conf" then
                print(...)
            end
            if v == "load" then
                self:initGameDirectory()
                for i, mode in ipairs(love.window.getFullscreenModes()) do
                    table.insert(XLE.optionsCached, #XLE.optionsCached + 1, {id = mode.width.. "x".. mode.height, text =  mode.width.. "x".. mode.height, value = mode  })
                end
            end
            for k, cb in pairs(self.callbacks) do
                if cb.type == v then
                    cb.callback(...)
                end
            end
            for _, scene in pairs(Scene.scenesInstances) do
                if scene[v] ~= nil and type(scene[v]) == "function" and scene.active then
                    scene[v](scene, ...)
                end
            end
            if v == "draw" then
                love.graphics.print('Memory actually used (in kB): ' .. collectgarbage('count'), 10,10)
            end
        end
    end
end

function XLE:addCallback( callbackName, type, callback )
    self.callbacks[callbackName] = {
        type = type,
        callback = callback
    }
end

function XLE:initGameDirectory ()
    love.filesystem.setIdentity(self.game_name, true)

    -- print("user directory"..love.filesystem.getSaveDirectory())

    if love.filesystem.getInfo(love.filesystem.getSaveDirectory(), "directory") == nil then
        local success = love.filesystem.createDirectory(love.filesystem.getSaveDirectory())
        if success then
            print("game directory created")
        else
            print("game directory already exist")
        end
    end

    local game_path = love.filesystem.getSaveDirectory()
end


return {
    Init = XLE,
    Scene = Scene,
    callbacks = callbacks,
}
