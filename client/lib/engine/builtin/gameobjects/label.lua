local LabelElement = require(_G.libDir .. "middleclass")("LabelElement")

function LabelElement:initialize( text, x, y)
    self.text = love.graphics.newText(love.graphics.getFont(), text)

    self.rect = {
        x = x or 0,
        y = y or 0
    }
end

function LabelElement:draw ()
    love.graphics.draw(self.text, self.rect.x + 2, self.rect.y + 2)
    love.graphics.setColor(1,1,1,1)
end

return LabelElement