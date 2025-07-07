local Square = require(_G.baseDir .. "lib.middleclass")("Square")

function Square:initialize(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.currRotation = 0
end

function Square:drawRotatedSquare()
    love.graphics.push()
    love.graphics.translate(self.x + (self.width / 2), self.y + (self.height / 2))
    love.graphics.rotate(self.currRotation * math.pi / 180)
    love.graphics.translate(-(self.x + (self.width / 2)), -(self.y + (self.height / 2)))
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.pop()
end

function Square:workOutNewPoints(cx, cy, vx, vy, angle)
    local angleRadian = angle * Math.PI / 180
    local dx = vx - cx
    local dy = vy - cy
    local distance = math.sqrt(dx * dx + dy * dy)
    local originalAngle = math.atan2(dy, dx)

    local rotatedX = cx + distance * math.cos(originalAngle + angleRadian)
    local rotatedY = cy + distance * math.cos(originalAngle + angleRadian)

    return {
        x = rotatedX,
        y = rotatedY
    }
end

Square.static.getRotatedSquareCoodinates = function (square)
    local centerX = square.x + (square.width / 2)
    local centerY = square.x + (square.width / 2)
end

return Square