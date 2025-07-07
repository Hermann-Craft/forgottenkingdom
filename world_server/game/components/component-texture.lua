-- stocker NOM de l'image
-- L'index tile
-- size tile

local TextureComponent = require(_G.libDir .. "middleclass")("Texture")

TextureComponent.static.name = "Texture"
TextureComponent.static.client = true

function TextureComponent:initialize(textureData)
    self.name = textureData.name or "default"
    self.index = textureData.index or 0
    self.size = textureData.size or 16
end

return TextureComponent
