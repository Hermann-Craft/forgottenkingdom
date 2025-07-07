local FormValidator = {}

-- Validation d'email
function FormValidator.validateEmail(email)
    if not email or email == "" then
        return false, "L'email est requis"
    end
    
    if string.len(email) < 5 then
        return false, "L'email est trop court"
    end
    
    if string.len(email) > 100 then
        return false, "L'email est trop long"
    end
    
    -- Validation regex basique pour email
    local pattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+%.[a-zA-Z][a-zA-Z]+$"
    if not string.match(email, pattern) then
        return false, "Format d'email invalide"
    end
    
    return true, ""
end

-- Validation de mot de passe
function FormValidator.validatePassword(password)
    if not password or password == "" then
        return false, "Le mot de passe est requis"
    end
    
    if string.len(password) < 6 then
        return false, "Minimum 6 caractères"
    end
    
    if string.len(password) > 50 then
        return false, "Maximum 50 caractères"
    end
    
    -- Vérifier qu'il y a au moins une lettre et un chiffre
    local hasLetter = string.match(password, "%a")
    local hasNumber = string.match(password, "%d")
    
    if not hasLetter then
        return false, "Doit contenir au moins une lettre"
    end
    
    if not hasNumber then
        return false, "Doit contenir au moins un chiffre"
    end
    
    return true, ""
end

-- Validation de confirmation de mot de passe
function FormValidator.validatePasswordConfirm(password, confirmPassword)
    if not confirmPassword or confirmPassword == "" then
        return false, "Confirmation requise"
    end
    
    if password ~= confirmPassword then
        return false, "Les mots de passe ne correspondent pas"
    end
    
    return true, ""
end

-- Validation de nom d'utilisateur/personnage
function FormValidator.validateUsername(username)
    if not username or username == "" then
        return false, "Le nom est requis"
    end
    
    if string.len(username) < 3 then
        return false, "Minimum 3 caractères"
    end
    
    if string.len(username) > 20 then
        return false, "Maximum 20 caractères"
    end
    
    -- Seulement lettres, chiffres et underscore
    if not string.match(username, "^[%w_]+$") then
        return false, "Lettres, chiffres et _ uniquement"
    end
    
    -- Ne doit pas commencer par un chiffre
    if string.match(username, "^%d") then
        return false, "Ne doit pas commencer par un chiffre"
    end
    
    return true, ""
end

-- Validation générique de champ requis
function FormValidator.validateRequired(value, fieldName)
    if not value or value == "" then
        return false, fieldName .. " est requis"
    end
    return true, ""
end

-- Créer un validateur pour un champ email
function FormValidator.createEmailValidator()
    return function(email)
        return FormValidator.validateEmail(email)
    end
end

-- Créer un validateur pour un champ mot de passe
function FormValidator.createPasswordValidator()
    return function(password)
        return FormValidator.validatePassword(password)
    end
end

-- Créer un validateur pour confirmation mot de passe
function FormValidator.createPasswordConfirmValidator(originalPasswordField)
    return function(confirmPassword)
        local originalPassword = originalPasswordField:getText()
        return FormValidator.validatePasswordConfirm(originalPassword, confirmPassword)
    end
end

-- Créer un validateur pour nom d'utilisateur
function FormValidator.createUsernameValidator()
    return function(username)
        return FormValidator.validateUsername(username)
    end
end

-- Validation d'un formulaire complet
function FormValidator.validateForm(fields)
    local isValid = true
    local errors = {}
    
    for fieldName, field in pairs(fields) do
        field:validate()
        if not field.isValid then
            isValid = false
            errors[fieldName] = field.validationMessage
        end
    end
    
    return isValid, errors
end

-- Utilitaire pour nettoyer les espaces
function FormValidator.sanitizeInput(input)
    if not input then return "" end
    -- Supprimer les espaces en début/fin
    input = string.gsub(input, "^%s*(.-)%s*$", "%1")
    return input
end

-- Validation en temps réel pour un formulaire
function FormValidator.setupRealTimeValidation(fields)
    for fieldName, field in pairs(fields) do
        if field.setOnChange then
            field:setOnChange(function(text)
                -- Déclencher la validation après un court délai
                field:validate()
            end)
        end
    end
end

return FormValidator 
