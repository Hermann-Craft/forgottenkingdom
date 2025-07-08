-- Test script pour Phase 1 : Infrastructure ECS villageois
-- Utiliser avec : love . test_villager_phase1

print("=== TEST PHASE 1 : Infrastructure ECS Villageois ===")

-- Initialiser les chemins globaux (comme dans main.lua)
_G.baseDir      = ""
_G.libDir       = _G.baseDir .. "lib."
_G.engineDir    = _G.libDir .. "engine."
_G.gameDir      = _G.baseDir .. "game."
_G.componentsDir = _G.gameDir .. "components."
_G.entitiesDir  = _G.gameDir .. "entities."
_G.systemsDir   = _G.gameDir .. "systems."
_G.worldsDir   = _G.gameDir .. "worlds."

print("Variables globales initialisées")

-- Test 1 : Charger les composants
print("\n1. Test chargement des composants...")
local success, error = pcall(function()
    local Components = require("game.components.components")
    assert(Components.Villager, "Composant Villager manquant")
    assert(Components.Hireable, "Composant Hireable manquant") 
    assert(Components.Worker, "Composant Worker manquant")
    assert(Components.Target, "Composant Target manquant")
    print("✓ Tous les composants chargés")
end)

if not success then
    print("❌ Erreur composants:", error)
    return
end

-- Test 2 : Charger TaskEnum
print("\n2. Test TaskEnum...")
local success, error = pcall(function()
    local TaskEnum = require("game.task-enum")
    assert(TaskEnum.Idle == 0, "TaskEnum.Idle incorrect")
    assert(TaskEnum.Follow == 1, "TaskEnum.Follow incorrect")
    assert(TaskEnum.ChopWood == 2, "TaskEnum.ChopWood incorrect")
    assert(TaskEnum.MineGold == 3, "TaskEnum.MineGold incorrect") 
    assert(TaskEnum.Defend == 4, "TaskEnum.Defend incorrect")
    print("✓ TaskEnum fonctionnel")
end)

if not success then
    print("❌ Erreur TaskEnum:", error)
    return
end

-- Test 3 : Créer une entité villageois
print("\n3. Test création entité villageois...")
local success, error = pcall(function()
    local VillagerEntity = require("game.entities.entity-villager")
    local villager = VillagerEntity:new("test_villager", {
        position = { x = 100, y = 100 },
        name = "Test Villager"
    })
    
    -- Vérifier les composants
    assert(villager:getComponent("Villager"), "Composant Villager manquant")
    assert(villager:getComponent("Hireable"), "Composant Hireable manquant")
    assert(villager:getComponent("Brain"), "Composant Brain manquant")
    assert(villager:getComponent("Target"), "Composant Target manquant")
    assert(villager:getComponent("Position"), "Composant Position manquant")
    
    -- Vérifier les valeurs par défaut
    local brain = villager:getComponent("Brain")
    local TaskEnum = require("game.task-enum")
    assert(brain.task == TaskEnum.Idle, "Tâche par défaut incorrecte")
    
    print("✓ Entité villageois créée avec succès")
    print("  - ID:", villager.id)
    print("  - Tâche:", brain.task, "(Idle)")
    print("  - Composants:", #villager.components)
end)

if not success then
    print("❌ Erreur création entité:", error)
    return
end

-- Test 4 : Test méthode de recrutement
print("\n4. Test méthode de recrutement...")
local success, error = pcall(function()
    local VillagerEntity = require("game.entities.entity-villager")
    local villager = VillagerEntity:new("test_recruit", {
        position = { x = 200, y = 200 },
        name = "Test Recruit"
    })
    
    -- Vérifier état initial
    assert(villager:getComponent("Hireable"), "Devrait être recrutables")
    assert(not villager:getComponent("Worker"), "Ne devrait pas être worker")
    assert(not villager:getComponent("Clan"), "Ne devrait pas avoir de clan")
    
    -- Recruter
    villager:recruit({ name = "TestClan", fame = 100 })
    
    -- Vérifier état après recrutement
    assert(not villager:getComponent("Hireable"), "Ne devrait plus être recrutables")
    assert(villager:getComponent("Worker"), "Devrait être worker")
    assert(villager:getComponent("Clan"), "Devrait avoir un clan")
    
    local clan = villager:getComponent("Clan")
    assert(clan.clanName == "TestClan", "Nom de clan incorrect")
    
    local brain = villager:getComponent("Brain")
    local TaskEnum = require("game.task-enum")
    assert(brain.task == TaskEnum.Follow, "Devrait être en tâche Follow")
    
    print("✓ Recrutement fonctionnel")
    print("  - Clan:", clan.clanName)
    print("  - Nouvelle tâche:", brain.task, "(Follow)")
end)

if not success then
    print("❌ Erreur recrutement:", error)
    return
end

-- Test 5 : Vérifier composition
print("\n5. Test composition...")
local success, error = pcall(function()
    local Compositions = require("game.compositions")
    assert(Compositions.Villager, "Composition Villager manquante")
    
    local expectedComponents = {
        "Position", "Orientation", "Dimension", "Speed", 
        "Life", "Name", "Texture", "Villager", "Brain", "Target"
    }
    
    for _, component in ipairs(expectedComponents) do
        local found = false
        for _, compName in ipairs(Compositions.Villager) do
            if compName == component then
                found = true
                break
            end
        end
        assert(found, "Composant " .. component .. " manquant dans composition")
    end
    
    print("✓ Composition Villager complète")
    print("  - Composants définis:", #Compositions.Villager)
end)

if not success then
    print("❌ Erreur composition:", error)
    return
end

print("\n=== 🎉 PHASE 1 RÉUSSIE ! ===")
print("✓ Infrastructure ECS villageois fonctionnelle")
print("✓ Composants créés et chargés")
print("✓ Entité villageois opérationnelle") 
print("✓ Système de recrutement de base")
print("✓ Composition définie")
print("\nPrêt pour Phase 2 : Système de spawn et IA de base")

return true 
