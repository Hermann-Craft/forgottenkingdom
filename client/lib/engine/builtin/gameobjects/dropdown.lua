local DropdownElement = require(_G.libDir .. "middleclass")("DropdownElement")

function DropdownElement:initialize(x, y, width, placeholder, options)
    self.x = x or 0
    self.y = y or 0
    self.width = width or 200
    self.height = 30
    self.placeholder = placeholder or "Sélectionner..."
    self.options = options or {}
    self.selectedIndex = 0
    self.selectedValue = nil
    self.isOpen = false
    self.focusedIndex = 0
    
    -- Style
    self.style = {
        backgroundColor = {0.1, 0.1, 0.1, 1},
        borderColor = {0.5, 0.5, 0.5, 1},
        borderColorFocused = {0.3, 0.6, 1, 1},
        textColor = {1, 1, 1, 1},
        placeholderColor = {0.6, 0.6, 0.6, 1},
        optionBackgroundColor = {0.15, 0.15, 0.15, 1},
        optionHoverColor = {0.3, 0.3, 0.4, 1},
        padding = 8
    }
    
    -- Callbacks
    self.onChangeCallback = nil
    self.onSelectCallback = nil
end

function DropdownElement:setOptions(options)
    self.options = options or {}
    self.selectedIndex = 0
    self.selectedValue = nil
    self.isOpen = false
end

function DropdownElement:addOption(value, label)
    table.insert(self.options, {value = value, label = label or value})
end

function DropdownElement:getSelectedValue()
    return self.selectedValue
end

function DropdownElement:getSelectedLabel()
    if self.selectedIndex > 0 and self.options[self.selectedIndex] then
        return self.options[self.selectedIndex].label
    end
    return nil
end

function DropdownElement:setSelectedValue(value)
    for i, option in ipairs(self.options) do
        if option.value == value then
            self.selectedIndex = i
            self.selectedValue = value
            if self.onChangeCallback then
                self.onChangeCallback(value, option.label)
            end
            return true
        end
    end
    return false
end

function DropdownElement:setOnChange(callback)
    self.onChangeCallback = callback
end

function DropdownElement:setOnSelect(callback)
    self.onSelectCallback = callback
end

function DropdownElement:toggle()
    self.isOpen = not self.isOpen
    if self.isOpen then
        self.focusedIndex = self.selectedIndex
    end
end

function DropdownElement:close()
    self.isOpen = false
end

function DropdownElement:selectOption(index)
    if index > 0 and index <= #self.options then
        local option = self.options[index]
        self.selectedIndex = index
        self.selectedValue = option.value
        self.isOpen = false
        
        if self.onChangeCallback then
            self.onChangeCallback(option.value, option.label)
        end
        
        if self.onSelectCallback then
            self.onSelectCallback(option.value, option.label)
        end
    end
end

function DropdownElement:update(dt)
    -- Pas de mise à jour spéciale nécessaire pour le moment
end

function DropdownElement:draw()
    local font = love.graphics.getFont()
    
    -- Fond principal
    love.graphics.setColor(self.style.backgroundColor)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    -- Bordure
    love.graphics.setColor(self.style.borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    -- Texte affiché
    local displayText = self.placeholder
    local textColor = self.style.placeholderColor
    
    if self.selectedIndex > 0 then
        displayText = self.options[self.selectedIndex].label
        textColor = self.style.textColor
    end
    
    love.graphics.setColor(textColor)
    local textY = self.y + (self.height - font:getHeight()) / 2
    love.graphics.print(displayText, self.x + self.style.padding, textY)
    
    -- Flèche dropdown
    love.graphics.setColor(self.style.textColor)
    local arrowX = self.x + self.width - 20
    local arrowY = self.y + self.height / 2
    if self.isOpen then
        -- Flèche vers le haut
        love.graphics.polygon("fill", 
            arrowX, arrowY - 3,
            arrowX + 6, arrowY + 3,
            arrowX - 6, arrowY + 3
        )
    else
        -- Flèche vers le bas
        love.graphics.polygon("fill", 
            arrowX, arrowY + 3,
            arrowX + 6, arrowY - 3,
            arrowX - 6, arrowY - 3
        )
    end
    
    -- Liste déroulante (si ouverte)
    if self.isOpen then
        local dropdownY = self.y + self.height
        local dropdownHeight = math.min(#self.options * self.height, 200)
        
        -- Fond de la liste
        love.graphics.setColor(self.style.optionBackgroundColor)
        love.graphics.rectangle("fill", self.x, dropdownY, self.width, dropdownHeight)
        
        -- Bordure de la liste
        love.graphics.setColor(self.style.borderColor)
        love.graphics.rectangle("line", self.x, dropdownY, self.width, dropdownHeight)
        
        -- Options
        for i, option in ipairs(self.options) do
            local optionY = dropdownY + (i - 1) * self.height
            
            -- Fond de l'option (hover ou sélectionnée)
            if i == self.focusedIndex then
                love.graphics.setColor(self.style.optionHoverColor)
                love.graphics.rectangle("fill", self.x, optionY, self.width, self.height)
            elseif i == self.selectedIndex then
                love.graphics.setColor(self.style.borderColorFocused)
                love.graphics.setColor(self.style.borderColorFocused[1], self.style.borderColorFocused[2], self.style.borderColorFocused[3], 0.3)
                love.graphics.rectangle("fill", self.x, optionY, self.width, self.height)
            end
            
            -- Texte de l'option
            love.graphics.setColor(self.style.textColor)
            local optionTextY = optionY + (self.height - font:getHeight()) / 2
            love.graphics.print(option.label, self.x + self.style.padding, optionTextY)
        end
    end
    
    -- Remettre la couleur par défaut
    love.graphics.setColor(1, 1, 1, 1)
end

function DropdownElement:mousepressed(x, y, button)
    if button == 1 then
        -- Clic sur le dropdown principal
        if x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height then
            self:toggle()
            return true
        end
        
        -- Clic sur une option (si ouvert)
        if self.isOpen then
            local dropdownY = self.y + self.height
            local dropdownHeight = math.min(#self.options * self.height, 200)
            
            if x >= self.x and x <= self.x + self.width and y >= dropdownY and y <= dropdownY + dropdownHeight then
                local optionIndex = math.floor((y - dropdownY) / self.height) + 1
                if optionIndex >= 1 and optionIndex <= #self.options then
                    self:selectOption(optionIndex)
                    return true
                end
            else
                -- Clic en dehors, fermer
                self:close()
            end
        end
    end
    return false
end

function DropdownElement:mousemoved(x, y)
    if self.isOpen then
        local dropdownY = self.y + self.height
        local dropdownHeight = math.min(#self.options * self.height, 200)
        
        if x >= self.x and x <= self.x + self.width and y >= dropdownY and y <= dropdownY + dropdownHeight then
            local optionIndex = math.floor((y - dropdownY) / self.height) + 1
            if optionIndex >= 1 and optionIndex <= #self.options then
                self.focusedIndex = optionIndex
            end
        else
            self.focusedIndex = 0
        end
    end
end

function DropdownElement:keypressed(key)
    if not self.isOpen then
        if key == "space" or key == "return" or key == "kpenter" then
            self:toggle()
            return true
        end
    else
        if key == "escape" then
            self:close()
            return true
        elseif key == "return" or key == "kpenter" then
            if self.focusedIndex > 0 then
                self:selectOption(self.focusedIndex)
            end
            return true
        elseif key == "up" then
            self.focusedIndex = math.max(1, self.focusedIndex - 1)
            return true
        elseif key == "down" then
            self.focusedIndex = math.min(#self.options, self.focusedIndex + 1)
            return true
        end
    end
    return false
end

function DropdownElement:isMouseOver(x, y)
    if self.isOpen then
        local dropdownY = self.y + self.height
        local dropdownHeight = math.min(#self.options * self.height, 200)
        return x >= self.x and x <= self.x + self.width and 
               ((y >= self.y and y <= self.y + self.height) or
                (y >= dropdownY and y <= dropdownY + dropdownHeight))
    else
        return x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height
    end
end

return DropdownElement 
