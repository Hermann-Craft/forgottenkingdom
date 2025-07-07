local SliderElement = require(_G.libDir .. "middleclass")("SliderElement")

function SliderElement:initialize(x, y, width, minValue, maxValue, initialValue, label)
    self.x = x or 0
    self.y = y or 0
    self.width = width or 200
    self.height = 20
    self.minValue = minValue or 0
    self.maxValue = maxValue or 100
    self.value = initialValue or minValue
    self.label = label or ""
    self.isDragging = false
    self.enabled = true
    
    -- Validation des valeurs
    if self.value < self.minValue then self.value = self.minValue end
    if self.value > self.maxValue then self.value = self.maxValue end
    
    -- Style
    self.style = {
        trackColor = {0.3, 0.3, 0.3, 1},
        fillColor = {0.3, 0.6, 1, 1},
        handleColor = {1, 1, 1, 1},
        handleColorHover = {0.9, 0.9, 0.9, 1},
        disabledColor = {0.5, 0.5, 0.5, 1},
        textColor = {1, 1, 1, 1},
        handleRadius = 8
    }
    
    -- Callbacks
    self.onChangeCallback = nil
    self.onReleaseCallback = nil
end

function SliderElement:setValue(value)
    local oldValue = self.value
    self.value = math.max(self.minValue, math.min(self.maxValue, value))
    
    if oldValue ~= self.value and self.onChangeCallback then
        self.onChangeCallback(self.value)
    end
end

function SliderElement:getValue()
    return self.value
end

function SliderElement:setRange(minValue, maxValue)
    self.minValue = minValue
    self.maxValue = maxValue
    self:setValue(self.value) -- Réappliquer la valeur pour respecter les nouvelles limites
end

function SliderElement:setEnabled(enabled)
    self.enabled = enabled
    if not enabled then
        self.isDragging = false
    end
end

function SliderElement:setOnChange(callback)
    self.onChangeCallback = callback
end

function SliderElement:setOnRelease(callback)
    self.onReleaseCallback = callback
end

function SliderElement:getHandleX()
    local progress = (self.value - self.minValue) / (self.maxValue - self.minValue)
    return self.x + progress * self.width
end

function SliderElement:valueFromX(x)
    local progress = (x - self.x) / self.width
    progress = math.max(0, math.min(1, progress))
    return self.minValue + progress * (self.maxValue - self.minValue)
end

function SliderElement:update(dt)
    -- Mise à jour en cas de drag
    if self.isDragging and love.mouse.isDown(1) then
        local mouseX = love.mouse.getX()
        local newValue = self:valueFromX(mouseX)
        self:setValue(newValue)
    elseif self.isDragging then
        -- Fin du drag
        self.isDragging = false
        if self.onReleaseCallback then
            self.onReleaseCallback(self.value)
        end
    end
end

function SliderElement:draw()
    local font = love.graphics.getFont()
    
    -- Couleurs selon l'état
    local trackColor = self.enabled and self.style.trackColor or self.style.disabledColor
    local fillColor = self.enabled and self.style.fillColor or self.style.disabledColor
    local handleColor = self.enabled and self.style.handleColor or self.style.disabledColor
    local textColor = self.enabled and self.style.textColor or self.style.disabledColor
    
    -- Label (si présent)
    if self.label ~= "" then
        love.graphics.setColor(textColor)
        love.graphics.print(self.label, self.x, self.y - 20)
    end
    
    -- Track (barre de fond)
    love.graphics.setColor(trackColor)
    love.graphics.rectangle("fill", self.x, self.y + self.height/2 - 2, self.width, 4)
    
    -- Fill (partie remplie)
    local fillWidth = (self.value - self.minValue) / (self.maxValue - self.minValue) * self.width
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", self.x, self.y + self.height/2 - 2, fillWidth, 4)
    
    -- Handle (poignée)
    local handleX = self:getHandleX()
    local handleY = self.y + self.height/2
    
    -- Effet hover sur la poignée
    local mouseX, mouseY = love.mouse.getPosition()
    local isHovering = self:isMouseOverHandle(mouseX, mouseY)
    
    if isHovering and self.enabled then
        love.graphics.setColor(self.style.handleColorHover)
    else
        love.graphics.setColor(handleColor)
    end
    
    love.graphics.circle("fill", handleX, handleY, self.style.handleRadius)
    
    -- Bordure de la poignée
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", handleX, handleY, self.style.handleRadius)
    
    -- Valeur affichée
    love.graphics.setColor(textColor)
    local valueText = string.format("%.0f", self.value)
    local textWidth = font:getWidth(valueText)
    love.graphics.print(valueText, self.x + self.width - textWidth, self.y - 20)
    
    -- Remettre la couleur par défaut
    love.graphics.setColor(1, 1, 1, 1)
end

function SliderElement:isMouseOverHandle(x, y)
    if not self.enabled then return false end
    
    local handleX = self:getHandleX()
    local handleY = self.y + self.height/2
    local distance = math.sqrt((x - handleX)^2 + (y - handleY)^2)
    return distance <= self.style.handleRadius
end

function SliderElement:isMouseOverTrack(x, y)
    if not self.enabled then return false end
    
    return x >= self.x and x <= self.x + self.width and 
           y >= self.y and y <= self.y + self.height
end

function SliderElement:mousepressed(x, y, button)
    if not self.enabled then return false end
    
    if button == 1 then
        -- Clic sur la poignée
        if self:isMouseOverHandle(x, y) then
            self.isDragging = true
            return true
        end
        
        -- Clic sur la track
        if self:isMouseOverTrack(x, y) then
            local newValue = self:valueFromX(x)
            self:setValue(newValue)
            self.isDragging = true
            return true
        end
    end
    
    return false
end

function SliderElement:mousereleased(x, y, button)
    if button == 1 and self.isDragging then
        self.isDragging = false
        if self.onReleaseCallback then
            self.onReleaseCallback(self.value)
        end
        return true
    end
    return false
end

function SliderElement:mousemoved(x, y)
    -- Le dragging est géré dans update() pour plus de fluidité
end

function SliderElement:keypressed(key)
    if not self.enabled then return false end
    
    local step = (self.maxValue - self.minValue) / 20 -- 5% steps
    
    if key == "left" then
        self:setValue(self.value - step)
        return true
    elseif key == "right" then
        self:setValue(self.value + step)
        return true
    elseif key == "home" then
        self:setValue(self.minValue)
        return true
    elseif key == "end" then
        self:setValue(self.maxValue)
        return true
    end
    
    return false
end

function SliderElement:isMouseOver(x, y)
    return self:isMouseOverTrack(x, y) or self:isMouseOverHandle(x, y)
end

-- Méthodes utilitaires pour des sliders liés (comme les stats)
function SliderElement:setLinkedSliders(sliders, totalPoints)
    self.linkedSliders = sliders
    self.totalPoints = totalPoints
    
    -- Callback spécial pour gérer la redistribution
    self:setOnChange(function(newValue)
        self:redistributePoints(newValue)
    end)
end

function SliderElement:redistributePoints(newValue)
    if not self.linkedSliders or not self.totalPoints then return end
    
    -- Calculer la différence
    local oldValue = self.previousValue or self.minValue
    local difference = newValue - oldValue
    self.previousValue = newValue
    
    -- Si on augmente cette stat, on doit réduire les autres
    if difference > 0 then
        local remaining = difference
        
        -- Réduire les autres sliders de manière proportionnelle
        for _, slider in ipairs(self.linkedSliders) do
            if slider ~= self and remaining > 0 then
                local canReduce = slider.value - slider.minValue
                local reduction = math.min(canReduce, remaining)
                slider:setValue(slider.value - reduction)
                remaining = remaining - reduction
            end
        end
        
        -- Si on ne peut pas tout réduire, ajuster notre valeur
        if remaining > 0 then
            self:setValue(newValue - remaining)
        end
    end
    
    -- Mettre à jour les valeurs précédentes pour tous les sliders
    for _, slider in ipairs(self.linkedSliders) do
        slider.previousValue = slider.value
    end
end

function SliderElement:getCurrentTotal()
    if not self.linkedSliders then return self.value end
    
    local total = 0
    for _, slider in ipairs(self.linkedSliders) do
        total = total + slider.value
    end
    return total
end

return SliderElement 
