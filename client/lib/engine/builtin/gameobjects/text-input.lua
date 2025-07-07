local TextInputElement = require(_G.libDir .. "middleclass")("TextInputElement")

-- Gestionnaire global du focus
if not _G.textInputFocused then
    _G.textInputFocused = nil
end

function TextInputElement:initialize(x, y, width, placeholder, isPassword)
    self.x = x or 0
    self.y = y or 0
    self.width = width or 200
    self.height = 30
    self.placeholder = placeholder or ""
    self.text = ""
    self.displayText = ""
    self.isPassword = isPassword or false
    self.focused = false
    self.cursorPos = 0
    self.cursorTimer = 0
    self.maxLength = 255
    
    -- Validation
    self.isValid = true
    self.validationMessage = ""
    self.validatorFunc = nil
    
    -- Événements
    self.onChangeCallback = nil
    self.onEnterCallback = nil
    self.onFocusCallback = nil
    self.onBlurCallback = nil
    
    -- Style
    self.style = {
        backgroundColor = {0.1, 0.1, 0.1, 1},
        borderColor = {0.5, 0.5, 0.5, 1},
        borderColorFocused = {0.3, 0.6, 1, 1},
        borderColorError = {1, 0.3, 0.3, 1},
        textColor = {1, 1, 1, 1},
        placeholderColor = {0.6, 0.6, 0.6, 1},
        padding = 8
    }
end

function TextInputElement:setText(text)
    self.text = text or ""
    self:updateDisplayText()
    self.cursorPos = string.len(self.text)
    self:validate()
    if self.onChangeCallback then
        self.onChangeCallback(self.text)
    end
end

function TextInputElement:getText()
    return self.text
end

function TextInputElement:setValidator(validatorFunc)
    self.validatorFunc = validatorFunc
    self:validate()
end

function TextInputElement:validate()
    if self.validatorFunc then
        self.isValid, self.validationMessage = self.validatorFunc(self.text)
    else
        self.isValid = true
        self.validationMessage = ""
    end
    return self.isValid, self.validationMessage
end

function TextInputElement:updateDisplayText()
    if self.isPassword and string.len(self.text) > 0 then
        self.displayText = string.rep("*", string.len(self.text))
    else
        self.displayText = self.text
    end
end

function TextInputElement:setOnChange(callback)
    self.onChangeCallback = callback
end

function TextInputElement:setOnEnter(callback)
    self.onEnterCallback = callback
end

function TextInputElement:setOnFocus(callback)
    self.onFocusCallback = callback
end

function TextInputElement:setOnBlur(callback)
    self.onBlurCallback = callback
end

function TextInputElement:focus()
    if not self.focused then
        -- Défocuser l'ancien champ
        if _G.textInputFocused and _G.textInputFocused ~= self then
            _G.textInputFocused:blur()
        end
        
        self.focused = true
        _G.textInputFocused = self
        love.keyboard.setTextInput(true)
        if self.onFocusCallback then
            self.onFocusCallback()
        end
    end
end

function TextInputElement:blur()
    if self.focused then
        self.focused = false
        if _G.textInputFocused == self then
            _G.textInputFocused = nil
            love.keyboard.setTextInput(false)
        end
        if self.onBlurCallback then
            self.onBlurCallback()
        end
    end
end

function TextInputElement:insertText(text)
    if string.len(self.text) < self.maxLength then
        local before = string.sub(self.text, 1, self.cursorPos)
        local after = string.sub(self.text, self.cursorPos + 1)
        self.text = before .. text .. after
        self.cursorPos = self.cursorPos + string.len(text)
        self:updateDisplayText()
        self:validate()
        
        if self.onChangeCallback then
            self.onChangeCallback(self.text)
        end
    end
end

function TextInputElement:deleteChar()
    if self.cursorPos > 0 then
        local before = string.sub(self.text, 1, self.cursorPos - 1)
        local after = string.sub(self.text, self.cursorPos + 1)
        self.text = before .. after
        self.cursorPos = self.cursorPos - 1
        self:updateDisplayText()
        self:validate()
        
        if self.onChangeCallback then
            self.onChangeCallback(self.text)
        end
    end
end

function TextInputElement:update(dt)
    self.cursorTimer = self.cursorTimer + dt
    if self.cursorTimer > 1 then
        self.cursorTimer = 0
    end
end

function TextInputElement:draw()
    local font = love.graphics.getFont()
    
    -- Déterminer la couleur de bordure
    local borderColor = self.style.borderColor
    if not self.isValid then
        borderColor = self.style.borderColorError
    elseif self.focused then
        borderColor = self.style.borderColorFocused
    end
    
    -- Fond
    love.graphics.setColor(self.style.backgroundColor)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    -- Bordure
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(self.focused and 2 or 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    love.graphics.setLineWidth(1)
    
    -- Texte ou placeholder
    local displayText = self.displayText
    local textColor = self.style.textColor
    
    if string.len(displayText) == 0 and self.placeholder then
        displayText = self.placeholder
        textColor = self.style.placeholderColor
    end
    
    love.graphics.setColor(textColor)
    local textY = self.y + (self.height - font:getHeight()) / 2
    love.graphics.print(displayText, self.x + self.style.padding, textY)
    
    -- Curseur clignotant si focalisé
    if self.focused and self.cursorTimer < 0.5 then
        local cursorText = string.sub(self.displayText, 1, self.cursorPos)
        local cursorX = self.x + self.style.padding + font:getWidth(cursorText)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", cursorX, textY, 1, font:getHeight())
    end
    
    -- Message de validation
    if not self.isValid and self.validationMessage then
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.print(self.validationMessage, self.x, self.y + self.height + 5)
    end
    
    -- Remettre la couleur par défaut
    love.graphics.setColor(1, 1, 1, 1)
end

function TextInputElement:mousepressed(x, y, button)
    if button == 1 then
        if x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height then
            self:focus()
            return true  -- Indiquer que l'événement a été traité
        end
    end
    return false
end

function TextInputElement:textinput(text)
    if self.focused then
        -- Filtrer les caractères de contrôle
        if string.byte(text) >= 32 then
            self:insertText(text)
        end
    end
end

function TextInputElement:keypressed(key)
    if self.focused then
        if key == "backspace" then
            self:deleteChar()
        elseif key == "return" or key == "kpenter" then
            if self.onEnterCallback then
                self.onEnterCallback(self.text)
            end
        elseif key == "left" then
            self.cursorPos = math.max(0, self.cursorPos - 1)
        elseif key == "right" then
            self.cursorPos = math.min(string.len(self.text), self.cursorPos + 1)
        elseif key == "home" then
            self.cursorPos = 0
        elseif key == "end" then
            self.cursorPos = string.len(self.text)
        end
    end
end

function TextInputElement:isMouseOver(x, y)
    return x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height
end

return TextInputElement 
