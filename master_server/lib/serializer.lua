-- Module de sérialisation personnalisé pour gérer les tokens JWT
-- Version serveur avec JSON de Lua pour plus de robustesse
local Serializer = {}

-- Fonction pour sérialiser les données (utilise JSON de Lua)
function Serializer.serialize(data)
    if _G.Json then
        return _G.Json:encode(data)
    else
        return Serializer.manualSerialize(data)
    end
end

-- Fonction pour désérialiser les données (utilise JSON de Lua)
function Serializer.deserialize(str)
    if _G.Json then
        local success, result = pcall(_G.Json.decode, _G.Json, str)
        if success then
            return result
        else
            print("[SERIALIZER] Erreur JSON, fallback manuel:", result)
            return Serializer.manualDeserialize(str)
        end
    else
        return Serializer.manualDeserialize(str)
    end
end

-- Sérialisation manuelle pour les structures simples (fallback)
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

-- Désérialisation manuelle simplifiée (fallback)
function Serializer.manualDeserialize(str)
    -- Pour les cas simples, on utilise une approche plus basique
    -- Cette fonction est un fallback, normalement JSON de Lua est utilisé
    
    -- Supprimer les espaces en début/fin
    str = str:match("^%s*(.-)%s*$")
    
    if str:sub(1,1) == "{" and str:sub(-1,-1) == "}" then
        -- C'est un objet JSON simple
        local result = {}
        local content = str:sub(2, -2)
        
        -- Splitting très simple pour les clés de base
        local current = ""
        local inString = false
        local escaped = false
        local depth = 0
        local key = nil
        local valueStart = nil
        
        for i = 1, #content do
            local char = content:sub(i, i)
            
            if escaped then
                escaped = false
                current = current .. char
            elseif char == '\\' then
                escaped = true
                current = current .. char
            elseif char == '"' then
                inString = not inString
                current = current .. char
            elseif not inString then
                if char == '{' or char == '[' then
                    depth = depth + 1
                    current = current .. char
                elseif char == '}' or char == ']' then
                    depth = depth - 1
                    current = current .. char
                elseif char == ':' and depth == 0 and not key then
                    key = current:match('^%s*"([^"]*)"'):gsub('\\"', '"')
                    current = ""
                elseif char == ',' and depth == 0 then
                    if key then
                        result[key] = Serializer.parseValue(current)
                        key = nil
                        current = ""
                    end
                else
                    current = current .. char
                end
            else
                current = current .. char
            end
        end
        
        -- Traiter la dernière paire clé-valeur
        if key and current ~= "" then
            result[key] = Serializer.parseValue(current)
        end
        
        return result
    else
        return Serializer.parseValue(str)
    end
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
        return Serializer.manualDeserialize(str)
    else
        return str
    end
end

-- Fonction spéciale pour les packets réseau
function Serializer.serializePacket(packet)
    -- Vérifier si le packet contient un token
    if packet.data and packet.data.token then
        local tokenLength = #packet.data.token
        print("[SERIALIZER] Token avant sérialisation:", tokenLength, "caractères")
        print("[SERIALIZER] Token début:", string.sub(packet.data.token, 1, 30) .. "...")
    end
    
    -- Debug pour les listes de personnages
    if packet.id == "list_character" and packet.data and packet.data.payload then
        print("[SERIALIZER] Sérialisation liste personnages")
        print("[SERIALIZER] Type payload avant:", type(packet.data.payload))
        print("[SERIALIZER] Nombre d'éléments:", #packet.data.payload)
        if #packet.data.payload > 0 then
            print("[SERIALIZER] Premier élément type:", type(packet.data.payload[1]))
            print("[SERIALIZER] Premier élément nom:", packet.data.payload[1].name)
            print("[SERIALIZER] Premier élément data type:", type(packet.data.payload[1].data))
        end
    end
    
    local serialized = Serializer.serialize(packet)
    
    if packet.data and packet.data.token then
        print("[SERIALIZER] Token après sérialisation:", #serialized, "caractères total")
        print("[SERIALIZER] Sérialisé début:", string.sub(serialized, 1, 50) .. "...")
    end
    
    -- Debug pour les listes de personnages après sérialisation
    if packet.id == "list_character" then
        print("[SERIALIZER] Après sérialisation liste personnages:")
        print("[SERIALIZER] Taille sérialisée:", #serialized)
        print("[SERIALIZER] Début sérialisé:", string.sub(serialized, 1, 200) .. "...")
    end
    
    return serialized
end

function Serializer.deserializePacket(str)
    print("[SERIALIZER] Désérialisation:", #str, "caractères")
    print("[SERIALIZER] JSON module disponible:", _G.Json and "oui" or "non")
    
    local result = Serializer.deserialize(str)
    
    -- Debug du token après désérialisation
    if result and result.data and result.data.token then
        print("[SERIALIZER] Token après désérialisation:", #result.data.token, "caractères")
        print("[SERIALIZER] Token début après:", string.sub(result.data.token, 1, 30) .. "...")
    end
    
    return result
end

-- Fonction de test pour vérifier la sérialisation
function Serializer.test()
    local testData = {
        id = "test",
        data = {
            email = "test@example.com",
            token = '{"typ":"JWT","alg":"HS256"}.{"email":"vincent@hermann.life","exp":1735747200,"iat":1735660800}.signature_part_here'
        }
    }
    
    print("[SERIALIZER] Test original:", #testData.data.token, "caractères")
    
    local serialized = Serializer.serialize(testData)
    print("[SERIALIZER] Test sérialisé:", #serialized, "caractères")
    
    local deserialized = Serializer.deserialize(serialized)
    print("[SERIALIZER] Test désérialisé:", #deserialized.data.token, "caractères")
    
    local success = deserialized.data.token == testData.data.token
    print("[SERIALIZER] Test réussi:", success)
    
    if not success then
        print("[SERIALIZER] Attendu:", testData.data.token)
        print("[SERIALIZER] Reçu:", deserialized.data.token)
    end
    
    return success
end

return Serializer 
