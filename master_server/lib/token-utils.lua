-- Utilitaires pour normaliser et comparer les tokens JWT entre formats bitser et JSON
local TokenUtils = {}

-- Fonction pour séparer correctement un token JWT en 3 parties
function TokenUtils.splitJWT(token)
    if not token then return nil end
    
    -- Un JWT a toujours exactement 2 points de séparation
    -- Nous devons trouver les positions de ces points en évitant ceux à l'intérieur des données
    local parts = {}
    local currentPart = ""
    local braceLevel = 0
    local inQuotes = false
    local escapeNext = false
    
    for i = 1, #token do
        local char = token:sub(i, i)
        
        if escapeNext then
            currentPart = currentPart .. char
            escapeNext = false
        elseif char == "\\" then
            currentPart = currentPart .. char
            escapeNext = true
        elseif char == '"' then
            currentPart = currentPart .. char
            inQuotes = not inQuotes
        elseif char == '{' and not inQuotes then
            currentPart = currentPart .. char
            braceLevel = braceLevel + 1
        elseif char == '}' and not inQuotes then
            currentPart = currentPart .. char
            braceLevel = braceLevel - 1
        elseif char == '.' and not inQuotes and braceLevel == 0 then
            -- C'est un point de séparation JWT
            table.insert(parts, currentPart)
            currentPart = ""
        else
            currentPart = currentPart .. char
        end
    end
    
    -- Ajouter la dernière partie
    if currentPart ~= "" then
        table.insert(parts, currentPart)
    end
    
    return parts
end

-- Fonction pour parser un token JSON string en objet Lua
function TokenUtils.parseJSONToken(jsonToken)
    if not jsonToken or type(jsonToken) ~= "string" then
        return nil
    end
    
    -- Extraire les parties du JWT avec notre méthode améliorée
    local parts = TokenUtils.splitJWT(jsonToken)
    
    if not parts or #parts ~= 3 then
        print("[TOKEN UTILS] JSON: Nombre de parties incorrect:", parts and #parts or 0)
        return nil
    end
    
    local headerStr, payloadStr, signature = parts[1], parts[2], parts[3]
    
    -- Parser le header JSON
    local header = {}
    header.typ = headerStr:match('"typ"%s*:%s*"([^"]+)"')
    header.alg = headerStr:match('"alg"%s*:%s*"([^"]+)"')
    
    -- Parser le payload JSON - utiliser des patterns plus robustes
    local payload = {}
    payload.email = payloadStr:match('"email"%s*:%s*"([^"]+)"')
    payload.iat = tonumber(payloadStr:match('"iat"%s*:%s*(%d+)'))
    payload.exp = tonumber(payloadStr:match('"exp"%s*:%s*(%d+)'))
    
    if not header.typ or not header.alg or not payload.email or not payload.iat or not payload.exp then
        return nil
    end
    
    return {
        header = header,
        payload = payload,
        signature = signature,
        raw = jsonToken
    }
end

-- Fonction pour normaliser un token bitser en format comparable
function TokenUtils.normalizeBitserToken(bitserToken)
    if not bitserToken or type(bitserToken) ~= "string" then
        return nil
    end
    
    -- Extraire les parties du JWT avec notre méthode améliorée
    local parts = TokenUtils.splitJWT(bitserToken)
    
    if not parts or #parts ~= 3 then
        print("[TOKEN UTILS] Bitser: Nombre de parties incorrect:", parts and #parts or 0)
        return nil
    end
    
    local headerStr, payloadStr, signature = parts[1], parts[2], parts[3]
    
    -- Parser le header (format bitser sans guillemets)
    local header = {}
    header.typ = headerStr:match('typ%s*:%s*([^,}]+)')
    header.alg = headerStr:match('alg%s*:%s*([^,}]+)')
    
    -- Parser le payload (format bitser sans guillemets) - utiliser des patterns plus robustes
    local payload = {}
    payload.email = payloadStr:match('email%s*:%s*([^,}]+)')
    payload.iat = tonumber(payloadStr:match('iat%s*:%s*(%d+)'))
    payload.exp = tonumber(payloadStr:match('exp%s*:%s*(%d+)'))
    
    if not header.typ or not header.alg or not payload.email or not payload.iat or not payload.exp then
        return nil
    end
    
    return {
        header = header,
        payload = payload,
        signature = signature,
        raw = bitserToken
    }
end

-- Fonction principale pour comparer deux tokens (peu importe leur format)
function TokenUtils.compareTokens(token1, token2)
    print("[TOKEN UTILS] Comparaison de tokens:")
    print("  Token 1 longueur:", token1 and #token1 or 0)
    print("  Token 2 longueur:", token2 and #token2 or 0)
    
    if not token1 or not token2 then
        print("[TOKEN UTILS] ❌ Un des tokens est manquant")
        return false
    end
    
    -- Déterminer le format de chaque token
    local parsed1, parsed2
    
    -- Token 1 - détecter le format
    if token1:find('"typ":"JWT"') then
        -- Format JSON
        parsed1 = TokenUtils.parseJSONToken(token1)
        print("[TOKEN UTILS] Token 1 détecté comme JSON")
    else
        -- Format bitser
        parsed1 = TokenUtils.normalizeBitserToken(token1)
        print("[TOKEN UTILS] Token 1 détecté comme bitser")
    end
    
    -- Token 2 - détecter le format
    if token2:find('"typ":"JWT"') then
        -- Format JSON
        parsed2 = TokenUtils.parseJSONToken(token2)
        print("[TOKEN UTILS] Token 2 détecté comme JSON")
    else
        -- Format bitser
        parsed2 = TokenUtils.normalizeBitserToken(token2)
        print("[TOKEN UTILS] Token 2 détecté comme bitser")
    end
    
    if not parsed1 or not parsed2 then
        print("[TOKEN UTILS] ❌ Erreur de parsing")
        return false
    end
    
    -- Comparer les données extraites
    local headerMatch = (parsed1.header.typ == parsed2.header.typ and 
                        parsed1.header.alg == parsed2.header.alg)
    
    local payloadMatch = (parsed1.payload.email == parsed2.payload.email and
                         parsed1.payload.iat == parsed2.payload.iat and
                         parsed1.payload.exp == parsed2.payload.exp)
    
    local signatureMatch = (parsed1.signature == parsed2.signature)
    
    print("[TOKEN UTILS] Résultats comparaison:")
    print("  Header match:", headerMatch)
    print("  Payload match:", payloadMatch)
    print("  Signature match:", signatureMatch)
    
    if parsed1.payload.email then
        print("  Email 1:", parsed1.payload.email)
    end
    if parsed2.payload.email then
        print("  Email 2:", parsed2.payload.email)
    end
    
    local result = headerMatch and payloadMatch and signatureMatch
    print("  ✅ Tokens correspondent:", result)
    
    return result
end

-- Fonction pour vérifier l'expiration d'un token
function TokenUtils.isTokenExpired(token)
    local parsed
    
    if token:find('"typ":"JWT"') then
        parsed = TokenUtils.parseJSONToken(token)
    else
        parsed = TokenUtils.normalizeBitserToken(token)
    end
    
    if not parsed or not parsed.payload.exp then
        return true -- Considérer comme expiré si on ne peut pas parser
    end
    
    return parsed.payload.exp < os.time()
end

-- Fonction de test pour vérifier le fonctionnement
function TokenUtils.test()
    local jsonToken = '{"typ":"JWT","alg":"HS256"}.{"email":"test@example.com","iat":1234567890,"exp":9999999999}.abcd1234'
    local bitserToken = '{typ:JWT,alg:HS256}.{email:test@example.com,iat:1234567890,exp:9999999999}.abcd1234'
    
    print("[TOKEN UTILS] Test de comparaison:")
    print("JSON:", jsonToken)
    print("Bitser:", bitserToken)
    
    local result = TokenUtils.compareTokens(jsonToken, bitserToken)
    print("Résultat test:", result)
    
    return result
end

return TokenUtils 
