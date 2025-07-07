local TextureManager = require(_G.libDir .. "middleclass")("TextureManager")

function TextureManager:initialize()
    self.textures = {}
    self.textureCache = {}
    self.basePath = "assets/textures/"
end

function TextureManager:loadTexture(textureName, category)
    local textureKey = category .. "/" .. textureName
    
    if self.textureCache[textureKey] then
        return self.textureCache[textureKey]
    end
    
    local fullPath = self.basePath .. category .. "/" .. textureName .. ".png"
    
    -- Vérifier si le fichier existe (Love2D ne lève pas d'erreur si le fichier n'existe pas)
    local success, texture = pcall(love.graphics.newImage, fullPath)
    
    if success then
        self.textureCache[textureKey] = texture
        print("[TEXTURE] Chargée:", fullPath)
        return texture
    else
        print("[TEXTURE] Erreur chargement:", fullPath)
        -- Retourner une texture par défaut (rectangle coloré)
        return self:getDefaultTexture(64, 64)
    end
end

function TextureManager:getDefaultTexture(width, height)
    local key = "default_" .. width .. "x" .. height
    
    if self.textureCache[key] then
        return self.textureCache[key]
    end
    
    -- Créer une texture par défaut (rectangle rouge)
    local imageData = love.image.newImageData(width, height)
    imageData:mapPixel(function(x, y, r, g, b, a)
        if x == 0 or x == width-1 or y == 0 or y == height-1 then
            return 1, 0, 0, 1 -- Bordure rouge
        else
            return 0.8, 0.8, 0.8, 1 -- Intérieur gris
        end
    end)
    
    local texture = love.graphics.newImage(imageData)
    self.textureCache[key] = texture
    
    return texture
end

function TextureManager:getTexture(textureName, category)
    category = category or "entities"
    return self:loadTexture(textureName, category)
end

function TextureManager:getTextureByComponent(textureComponent)
    if not textureComponent or not textureComponent.name then
        return self:getDefaultTexture(32, 32)
    end
    
    local textureName = textureComponent.name
    local size = textureComponent.size or 32
    
    -- Essayer de charger la texture depuis entities/
    local texture = self:getTexture(textureName, "entities")
    
    if not texture then
        texture = self:getDefaultTexture(size, size)
    end
    
    return texture
end

function TextureManager:preloadTextures()
    -- Précharger les textures principales
    local texturesToPreload = {
        { name = "goldmine", category = "entities" },
        { name = "player", category = "entities" },
    }
    
    for _, textureInfo in ipairs(texturesToPreload) do
        self:loadTexture(textureInfo.name, textureInfo.category)
    end
    
    print("[TEXTURE] Préchargement terminé")
end

function TextureManager:clearCache()
    for key, texture in pairs(self.textureCache) do
        texture:release()
    end
    self.textureCache = {}
    print("[TEXTURE] Cache vidé")
end

function TextureManager:getStats()
    local count = 0
    for _ in pairs(self.textureCache) do
        count = count + 1
    end
    
    return {
        texturesLoaded = count,
        cacheSize = count
    }
end

return TextureManager 
