local InputElement = require(_G.libDir .. "middleclass")("InputElement")

function InputElement:initialize( x, y)
    self.value = ""

    self.text = love.graphics.newText(love.graphics.getFont(), self.value)

    self.rect = {
        x = x or 0,
        y = y or 0
    }

    self.capturedFocus = false
end

function InputElement:draw ()
    local mx, my = love.mouse.getPosition()
    if not self.disabled then
        if mx > self.rect.x and mx < self.rect.x + self.text:getWidth() + 8
        and my > self.rect.y and my < self.rect.y + self.text:getHeight() + 8 then
            love.graphics.rectangle("fill", self.rect.x, self.rect.y, self.text:getWidth() + 8, self.text:getHeight() + 8)
            love.graphics.setColor(0,0,0,1)
            love.graphics.draw(self.text, self.rect.x + 2, self.rect.y + 2)
            love.graphics.setColor(1,1,1,1)
        else
            love.graphics.rectangle("line", self.rect.x, self.rect.y, self.text:getWidth() + 8, self.text:getHeight() + 8 )
            love.graphics.draw(self.text, self.rect.x + 2, self.rect.y + 2)
        end
    else
        love.graphics.setColor(128/255,128/255,128/255,1)
        love.graphics.rectangle("line", self.rect.x, self.rect.y, self.text:getWidth() + 8, self.text:getHeight() + 8 )
        love.graphics.draw(self.text, self.rect.x + 2, self.rect.y + 2)
        love.graphics.setColor(1,1,1,1)
    end
end

function InputElement:keypressed (key, isrepeat)
    while isrepeat do
        self.value = self.value .. key
        self.text:set(self.value)
    end  
end

function InputElement:mousereleased (x, y, button)
    if x > self.rect.x and x < self.rect.x + self.text:getWidth() + 8 and y > self.rect.y and y < self.rect.y + self.text:getHeight() + 8 then
        self.capturedFocus = true
    else
        self.capturedFocus = false
    end
end

function InputElement:mousepressed ()
end

return InputElement