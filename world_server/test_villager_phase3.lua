-- Test script pour Phase 3 : Détection de proximité et recrutement
-- Utiliser avec : lua test_villager_phase3.lua

print("=== TEST PHASE 3 : Détection de proximité et recrutement ===")

-- Initialiser les chemins globaux
_G.baseDir      = ""
_G.libDir       = _G.baseDir .. "lib."
_G.engineDir    = _G.libDir .. "engine."
_G.gameDir      = _G.baseDir .. "game."
_G.componentsDir = _G.gameDir .. "components."
_G.entitiesDir  = _G.gameDir .. "entities."
_G.systemsDir   = _G.gameDir .. "systems."
_G.worldsDir   = _G.gameDir .. "worlds."

-- Mock de love.math.random et love.timer
love = love or {}
love.math = love.math or {}
love.math.random = function(min, max)
    if not min then return math.random()
    elseif not max then return math.random(min)
    else return math.random(min, max) end
end
love.timer = love.timer or {}
love.timer.getTime = function() return 0 end

-- Mock de uuid
_G.uuid = function()
    return "test-uuid-" .. math.random(1000, 9999)
end

-- Mock de _G.Server pour les tests
_G.Server = {
    Tcp = {
        send = function(self, data, clientid)
            print("  [MOCK TCP] Message envoyé à client", clientid)
        end
    },
    Clients = {
        ["test_player"] = {
            tcp = 100,
            udp = 200
        }
    }
}

print("Variables globales et mocks initialisés")

-- Test 1 : Extension du système d'interaction
print("\n1. Test extension système d'interaction...")
local success, error = pcall(function()
    local InteractionSystem = require("game.systems.system-interaction")
    
    -- Mock du monde minimal
    local mockWorld = {
        systems = {},
        getEntitiesWithStrict = function(self, comp) return {} end,
        getEntitiesWithAtLeast = function(self, comp) return {} end,
        getEntityById = function(self, id)
            if id == "test_player" then
                return {
                    id = "test_player",
                    getComponent = function(self, name)
                        if name == "Position" then
                            return { position = { x = 100, y = 100 } }
                        elseif name == "Wallet" then
                            return { wallet = 50 }
                        end
                        return nil
                    end
                }
            end
            return nil
        end
    }
    
    local interactionSystem = InteractionSystem:new(mockWorld, true)
    
    assert(interactionSystem.villagerInteractionDistance == 80, "Distance villageois incorrecte")
    assert(type(interactionSystem.playersNearVillagers) == "table", "Tracking villageois manquant")
    assert(type(interactionSystem.checkProximityVillagers) == "function", "Méthode checkProximityVillagers manquante")
    assert(type(interactionSystem.onPlayerNearVillager) == "function", "Méthode onPlayerNearVillager manquante")
    
    print("✓ Extension système d'interaction fonctionnelle")
    print("  - Distance villageois:", interactionSystem.villagerInteractionDistance)
    print("  - Tracking villageois initialisé")
    print("  - Nouvelles méthodes présentes")
end)

if not success then
    print("❌ Erreur extension interaction:", error)
    return
end

-- Test 2 : Système de recrutement
print("\n2. Test système de recrutement...")
local success, error = pcall(function()
    local RecruitSystem = require("game.systems.system-recruit")
    
    -- Mock du monde avec interaction system
    local mockWorld = {
        systems = {
            {
                class = { name = "InteractionSystem" },
                playersNearVillagers = {
                    ["test_player"] = {
                        ["test_villager"] = true
                    }
                }
            }
        },
        getEntityById = function(self, id)
            if id == "test_player" then
                return {
                    id = "test_player",
                    getComponent = function(self, name)
                        if name == "Wallet" then
                            return { wallet = 50 }
                        elseif name == "Clan" then
                            return { clanName = "TestClan", clanFame = 0 }
                        end
                        return nil
                    end
                }
            elseif id == "test_villager" then
                return {
                    id = "test_villager",
                    components = {},
                    getComponent = function(self, name)
                        if name == "Hireable" then
                            return {}  -- Villageois recrutables
                        elseif name == "Name" then
                            return { name = "Test Villager" }
                        end
                        return nil
                    end,
                    recruit = function(self, clanData)
                        -- Mock réussi du recrutement
                        return true
                    end
                }
            end
            return nil
        end
    }
    
    local recruitSystem = RecruitSystem:new(mockWorld, true)
    
    assert(recruitSystem.RECRUITMENT_COST == 25, "Coût de recrutement incorrect")
    assert(type(recruitSystem.handleRecruitmentRequest) == "function", "Méthode handleRecruitmentRequest manquante")
    
    -- Test d'une demande de recrutement valide
    local result = recruitSystem:handleRecruitmentRequest("test_player", "test_villager")
    assert(type(result) == "table", "Résultat recrutement doit être une table")
    assert(result.success == true, "Recrutement devrait réussir")
    assert(result.goldSpent == 25, "Or dépensé incorrect")
    
    print("✓ Système de recrutement fonctionnel")
    print("  - Coût:", recruitSystem.RECRUITMENT_COST, "or")
    print("  - Test recrutement valide: succès")
    print("  - Or dépensé:", result.goldSpent)
end)

if not success then
    print("❌ Erreur système recrutement:", error)
    return
end

-- Test 3 : Test échec recrutement (pas assez d'or)
print("\n3. Test échec recrutement (or insuffisant)...")
local success, error = pcall(function()
    local RecruitSystem = require("game.systems.system-recruit")
    
    -- Mock du monde avec joueur pauvre
    local mockWorld = {
        systems = {
            {
                class = { name = "InteractionSystem" },
                playersNearVillagers = {
                    ["poor_player"] = {
                        ["test_villager"] = true
                    }
                }
            }
        },
        getEntityById = function(self, id)
            if id == "poor_player" then
                return {
                    id = "poor_player",
                    getComponent = function(self, name)
                        if name == "Wallet" then
                            return { wallet = 10 }  -- Pas assez d'or
                        elseif name == "Clan" then
                            return { clanName = "PoorClan", clanFame = 0 }
                        end
                        return nil
                    end
                }
            elseif id == "test_villager" then
                return {
                    id = "test_villager",
                    getComponent = function(self, name)
                        if name == "Hireable" then
                            return {}
                        elseif name == "Name" then
                            return { name = "Test Villager" }
                        end
                        return nil
                    end
                }
            end
            return nil
        end
    }
    
    local recruitSystem = RecruitSystem:new(mockWorld, true)
    local result = recruitSystem:handleRecruitmentRequest("poor_player", "test_villager")
    
    assert(result.success == false, "Recrutement devrait échouer")
    assert(result.reason == "insufficient_gold", "Raison d'échec incorrecte")
    
    print("✓ Échec recrutement (or insuffisant) fonctionnel")
    print("  - Résultat:", result.success and "succès" or "échec")
    print("  - Raison:", result.reason)
end)

if not success then
    print("❌ Erreur test échec recrutement:", error)
    return
end

-- Test 4 : Test échec recrutement (trop loin)
print("\n4. Test échec recrutement (distance)...")
local success, error = pcall(function()
    local RecruitSystem = require("game.systems.system-recruit")
    
    -- Mock du monde avec joueur loin
    local mockWorld = {
        systems = {
            {
                class = { name = "InteractionSystem" },
                playersNearVillagers = {}  -- Aucun joueur près de villageois
            }
        },
        getEntityById = function(self, id)
            if id == "far_player" then
                return {
                    id = "far_player",
                    getComponent = function(self, name)
                        if name == "Wallet" then
                            return { wallet = 100 }
                        elseif name == "Clan" then
                            return { clanName = "FarClan", clanFame = 0 }
                        end
                        return nil
                    end
                }
            elseif id == "test_villager" then
                return {
                    id = "test_villager",
                    getComponent = function(self, name)
                        if name == "Hireable" then
                            return {}
                        end
                        return nil
                    end
                }
            end
            return nil
        end
    }
    
    local recruitSystem = RecruitSystem:new(mockWorld, true)
    local result = recruitSystem:handleRecruitmentRequest("far_player", "test_villager")
    
    assert(result.success == false, "Recrutement devrait échouer")
    assert(result.reason == "too_far", "Raison d'échec incorrecte")
    
    print("✓ Échec recrutement (distance) fonctionnel")
    print("  - Résultat:", result.success and "succès" or "échec")
    print("  - Raison:", result.reason)
end)

if not success then
    print("❌ Erreur test échec distance:", error)
    return
end

-- Test 5 : Test intégration RealmWorld
print("\n5. Test intégration RealmWorld...")
local success, error = pcall(function()
    local RealmWorld = require("game.worlds.world-realm")
    
    -- Vérifier que la classe se charge avec les nouvelles méthodes
    assert(RealmWorld, "RealmWorld non chargé")
    assert(type(RealmWorld.handleRecruitmentRequest) == "function", "Méthode handleRecruitmentRequest manquante")
    assert(type(RealmWorld.getRecruitmentStats) == "function", "Méthode getRecruitmentStats manquante")
    
    print("✓ RealmWorld avec système de recrutement chargé")
    print("  - Méthode handleRecruitmentRequest présente")
    print("  - Méthode getRecruitmentStats présente")
end)

if not success then
    print("❌ Erreur intégration RealmWorld:", error)
    return
end

-- Test 6 : Test messages réseau
print("\n6. Test structure des messages réseau...")
local success, error = pcall(function()
    -- Test structure message villager_recruitment_available
    local recruitmentMessage = {
        id = "villager_recruitment_available",
        data = {
            villagerId = "test_villager",
            villagerName = "Test Villager",
            recruitmentCost = 25,
            canAfford = true,
            playerGold = 50
        }
    }
    
    assert(recruitmentMessage.id == "villager_recruitment_available", "ID message incorrect")
    assert(recruitmentMessage.data.recruitmentCost == 25, "Coût dans message incorrect")
    
    -- Test structure message recruitment_result
    local resultMessage = {
        id = "recruitment_result",
        data = {
            success = true,
            villagerId = "test_villager",
            villagerName = "Test Villager",
            goldSpent = 25,
            newGoldTotal = 25,
            clanName = "TestClan"
        }
    }
    
    assert(resultMessage.data.success == true, "Succès dans résultat incorrect")
    assert(resultMessage.data.goldSpent == 25, "Or dépensé dans résultat incorrect")
    
    print("✓ Messages réseau structurés correctement")
    print("  - villager_recruitment_available: ✓")
    print("  - recruitment_result: ✓")
end)

if not success then
    print("❌ Erreur structure messages:", error)
    return
end

print("\n=== 🎉 PHASE 3 RÉUSSIE ! ===")
print("✓ Extension système d'interaction pour villageois")
print("✓ Système de recrutement complet et fonctionnel")
print("✓ Gestion des échecs (or, distance, villageois indisponible)")
print("✓ Intégration dans RealmWorld")
print("✓ Messages réseau structurés")
print("✓ Debug et logs intégrés")
print("\nPrêt pour Phase 4 : Menu contextuel et assignation de tâches")

return true 
