local Point = require(_G.baseDir .. "lib.middleclass")("Point")

function Point:initialize(x, y)
    self.x = x
    self.y = y
end

return Point