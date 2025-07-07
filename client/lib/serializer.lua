-- Module de sérialisation personnalisé pour gérer les tokens JWT
-- Version simplifiée sans dépendances JSON
local Serializer = {}

-- Fonction pour sérialiser les données (alternative à _G.bitser.dumps)
function Serializer.serialize(data)
    return Serializer.manualSerialize(data)
end

-- Fonction pour désérialiser les données (alternative à _G.bitser.loads)
function Serializer.deserialize(str)
    return Serializer.manualDeserialize(str)
end

-- Sérialisation manuelle pour les structures simples
function Serializer.manualSerialize(data)
    if type(data) == "table" then
        local result = "{"
        local first = true
        
        for k, v in pairs(data) do
            if not first then
                result = result .. ","
            end
            first = false
            
            result = result .. '"' .. tostring(k) .. '":' .. Serializer.serializeValue(v)
        end
        
        result = result .. "}"
        return result
    else
        return Serializer.serializeValue(data)
    end
end

function Serializer.serializeValue(value)
    local t = type(value)
    
    if t == "string" then
        -- Échapper les caractères spéciaux
        local escaped = value:gsub('\\', '\\\\')
                            :gsub('"', '\\"')
                            :gsub('\n', '\\n')
                            :gsub('\r', '\\r')
                            :gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    elseif t == "number" then
        return tostring(value)
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "nil" then
        return "null"
    elseif t == "table" then
        return Serializer.manualSerialize(value)
    else
        return '"' .. tostring(value) .. '"'
    end
end

-- Désérialisation manuelle améliorée
function Serializer.manualDeserialize(str)
    -- Supprimer les espaces en début/fin
    str = str:match("^%s*(.-)%s*$")
    
    if str:sub(1,1) == "{" and str:sub(-1,-1) == "}" then
        -- C'est un objet JSON
        return Serializer.parseObject(str)
    else
        return Serializer.parseValue(str)
    end
end

function Serializer.parseObject(str)
    local result = {}
    local content = str:sub(2, -2) -- Enlever les accolades
    
    -- Parser plus robuste pour les objets JSON
    local i = 1
    while i <= #content do
        -- Trouver la prochaine clé
        local keyStart = content:find('"', i)
        if not keyStart then break end
        
        local keyEnd = content:find('"', keyStart + 1)
        if not keyEnd then break end
        
        local key = content:sub(keyStart + 1, keyEnd - 1)
        
        -- Trouver le ':'
        local colonPos = content:find(':', keyEnd)
        if not colonPos then break end
        
        -- Trouver la valeur
        local valueStart = colonPos + 1
        while valueStart <= #content and content:sub(valueStart, valueStart):match('%s') do
            valueStart = valueStart + 1
        end
        
        local valueEnd = valueStart
        local braceCount = 0
        local bracketCount = 0
        local inString = false
        local escaped = false
        
        while valueEnd <= #content do
            local char = content:sub(valueEnd, valueEnd)
            
            if escaped then
                escaped = false
            elseif char == '\\' then
                escaped = true
            elseif char == '"' then
                inString = not inString
            elseif not inString then
                if char == '{' then
                    braceCount = braceCount + 1
                elseif char == '}' then
                    braceCount = braceCount - 1
                elseif char == '[' then
                    bracketCount = bracketCount + 1
                elseif char == ']' then
                    bracketCount = bracketCount - 1
                elseif char == ',' and braceCount == 0 and bracketCount == 0 then
                    break
                end
            end
            
            valueEnd = valueEnd + 1
        end
        
        if valueEnd > #content then
            valueEnd = #content + 1
        end
        
        local valueStr = content:sub(valueStart, valueEnd - 1):match("^%s*(.-)%s*$")
        result[key] = Serializer.parseValue(valueStr)
        
        i = valueEnd + 1
    end
    
    return result
end

function Serializer.parseArray(str)
    local result = {}
    local content = str:sub(2, -2) -- Enlever les crochets
    
    -- Si l'array est vide
    if content:match("^%s*$") then
        return result
    end
    
    -- Parser les éléments de l'array
    local i = 1
    local elementIndex = 1
    
    while i <= #content do
        -- Trouver le début de l'élément
        while i <= #content and content:sub(i, i):match('%s') do
            i = i + 1
        end
        
        if i > #content then break end
        
        -- Trouver la fin de l'élément
        local elementStart = i
        local elementEnd = i
        local braceCount = 0
        local bracketCount = 0
        local inString = false
        local escaped = false
        
        while elementEnd <= #content do
            local char = content:sub(elementEnd, elementEnd)
            
            if escaped then
                escaped = false
            elseif char == '\\' then
                escaped = true
            elseif char == '"' then
                inString = not inString
            elseif not inString then
                if char == '{' then
                    braceCount = braceCount + 1
                elseif char == '}' then
                    braceCount = braceCount - 1
                elseif char == '[' then
                    bracketCount = bracketCount + 1
                elseif char == ']' then
                    bracketCount = bracketCount - 1
                elseif char == ',' and braceCount == 0 and bracketCount == 0 then
                    break
                end
            end
            
            elementEnd = elementEnd + 1
        end
        
        if elementEnd > #content then
            elementEnd = #content + 1
        end
        
        local elementStr = content:sub(elementStart, elementEnd - 1):match("^%s*(.-)%s*$")
        result[elementIndex] = Serializer.parseValue(elementStr)
        elementIndex = elementIndex + 1
        
        i = elementEnd + 1
    end
    
    return result
end

function Serializer.parseValue(str)
    str = str:match("^%s*(.-)%s*$") -- Trim
    
    if str:sub(1,1) == '"' and str:sub(-1,-1) == '"' then
        -- String - gestion de l'échappement
        local unescaped = str:sub(2, -2)
        unescaped = unescaped:gsub('\\"', '"')
                            :gsub('\\\\', '\\')
                            :gsub('\\n', '\n')
                            :gsub('\\r', '\r')
                            :gsub('\\t', '\t')
        return unescaped
    elseif str == "true" then
        return true
    elseif str == "false" then
        return false
    elseif str == "null" then
        return nil
    elseif tonumber(str) then
        return tonumber(str)
    elseif str:sub(1,1) == "{" then
        return Serializer.parseObject(str)
    elseif str:sub(1,1) == "[" and str:sub(-1,-1) == "]" then
        return Serializer.parseArray(str)
    else
        return str
    end
end

-- Fonction spéciale pour les packets réseau
function Serializer.serializePacket(packet)
    return Serializer.serialize(packet)
end

function Serializer.deserializePacket(str)
    local result = Serializer.deserialize(str)
    
    return result
end

-- Fonction de test pour vérifier la sérialisation
function Serializer.test()
    local testData = {
        id = "test",
        data = {
            email = "test@example.com",
            token = "very_long_token_that_should_not_be_truncated_at_all_because_it_contains_important_authentication_information_that_needs_to_be_preserved_completely"
        }
    }
    
    print("[SERIALIZER] Test original:", #testData.data.token, "caractères")
    
    local serialized = Serializer.serialize(testData)
    print("[SERIALIZER] Test sérialisé:", #serialized, "caractères")
    
    local deserialized = Serializer.deserialize(serialized)
    print("[SERIALIZER] Test désérialisé:", #deserialized.data.token, "caractères")
    
    return deserialized.data.token == testData.data.token
end

return Serializer 
