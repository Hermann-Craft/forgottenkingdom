function love.conf(t)
    t.title = "Forgotten Kingdom"
    t.author = "BAW Developpement"
    t.version = "11.4"
    t.console = true
    
    t.window.title = "Forgotten Kingdom"
    t.window.width = 1024
    t.window.height = 768
    t.window.resizable = true
    t.window.minwidth = 800
    t.window.minheight = 600
    
    t.modules.joystick = true
    t.modules.audio = true
    t.modules.keyboard = true
    t.modules.mouse = true
    t.modules.timer = true
    t.modules.event = true
    t.modules.sound = true
    t.modules.system = true
    t.modules.graphics = true
    t.modules.window = true
end 
