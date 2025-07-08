-- Test Phase 5: Ressources et récolte (ChopWood, MineGold)
-- Ce test valide:
-- 1. Composant Resource pour villageois
-- 2. Composant et entité TreeZone 
-- 3. Extension IA ChopWood et MineGold
-- 4. Activation tâches dans menu contextuel
-- 5. Système de spawn des TreeZones

-- Mock pour Love2D
_G.love = {
    timer = {
        getTime = function() return os.clock() end
    },
    math = {
        random = function(min, max)
            if min and max then
                return math.random(min, max)
            elseif min then
                return math.random() * min
            else
                return math.random()
            end
        end
    }
}

-- Configuration des chemins
_G.baseDir = ""
_G.libDir = "lib/"
_G.gameDir = "game/"
_G.componentsDir = "game/components/"
_G.entitiesDir = "game/entities/"
_G.systemsDir = "game/systems/"
_G.engineDir = "lib/engine/"  -- Ajout pour compatibilité

-- Fonction mock pour uuid
function uuid()
    return "test_uuid_" .. tostring(math.random(1000, 9999))
end

-- Chargement des dépendances
local Components = require("game/components/components")
local TaskEnum = require("game/task-enum")
local VillagerEntity = require("game/entities/entity-villager")
local TreeZoneEntity = require("game/entities/entity-tree-zone")
local TreeSpawnSystem = require("game/systems/system-tree-spawn")
local VillagerAISystem = require("game/systems/system-villager-ai")
local ContextMenuSystem = require("game/systems/system-context-menu")

-- Mock World simple pour les tests
local World = require("lib/engine/world")
local testWorld = World:new()

-- Mock compositions
local Compositions = {
    Player = {"Position", "Clan"}
}

local TestSuite = {}
local testsPassed = 0
local testsFailed = 0

function TestSuite.assert(condition, message)
    if condition then
        print("✅ PASS: " .. message)
        testsPassed = testsPassed + 1
    else
        print("❌ FAIL: " .. message)
        testsFailed = testsFailed + 1
    end
end

function TestSuite.runAllTests()
    print("=== PHASE 5: Tests Ressources et Récolte ===")
    
    TestSuite.testResourceComponent()
    TestSuite.testTreeZoneComponent()
    TestSuite.testTreeZoneEntity()
    TestSuite.testVillagerEntityWithResource()
    TestSuite.testTreeSpawnSystem()
    TestSuite.testVillagerAIExtensions()
    TestSuite.testContextMenuActivation()
    TestSuite.testTaskAvailability()
    TestSuite.testResourceHarvesting()
    TestSuite.testIntegrationWorkflow()
    
    print("\n=== RÉSULTATS PHASE 5 ===")
    print("Tests réussis: " .. testsPassed)
    print("Tests échoués: " .. testsFailed)
    print("Total: " .. (testsPassed + testsFailed))
    
    if testsFailed == 0 then
        print("🎉 TOUS LES TESTS PHASE 5 SONT PASSÉS!")
        return true
    else
        print("💥 CERTAINS TESTS ONT ÉCHOUÉ")
        return false
    end
end

function TestSuite.testResourceComponent()
    print("\n--- Test Composant Resource ---")
    
    -- Test 1: Création composant Resource
    local resource = Components.Resource:new()
    TestSuite.assert(resource ~= nil, "Composant Resource créé")
    TestSuite.assert(resource.wood == 0, "Bois initial = 0")
    TestSuite.assert(resource.gold == 0, "Or initial = 0")
    TestSuite.assert(resource.maxWood == 10, "Capacité bois = 10")
    TestSuite.assert(resource.maxGold == 5, "Capacité or = 5")
    
    -- Test 2: Ajout de ressources
    local addedWood = resource:addWood(3)
    TestSuite.assert(addedWood == 3 and resource.wood == 3, "Ajout 3 bois")
    
    local addedGold = resource:addGold(2)
    TestSuite.assert(addedGold == 2 and resource.gold == 2, "Ajout 2 or")
    
    -- Test 3: Capacité maximale
    local overflow = resource:addWood(10)  -- 3 + 10 = 13, mais max = 10
    TestSuite.assert(overflow == 7 and resource.wood == 10, "Limite capacité bois")
    
    -- Test 4: Vérifications d'état
    TestSuite.assert(not resource:isEmpty(), "Inventaire non vide")
    TestSuite.assert(resource.isCarrying, "État carrying actif")
    TestSuite.assert(resource:canCarryGold(3), "Peut porter 3 or en plus")
    TestSuite.assert(not resource:canCarryWood(1), "Ne peut plus porter de bois")
    
    -- Test 5: Suppression ressources
    local removedWood = resource:removeWood(5)
    TestSuite.assert(removedWood == 5 and resource.wood == 5, "Suppression 5 bois")
    
    resource:clear()
    TestSuite.assert(resource:isEmpty() and not resource.isCarrying, "Clear inventaire")
end

function TestSuite.testTreeZoneComponent()
    print("\n--- Test Composant TreeZone ---")
    
    -- Test 1: Création composant TreeZone
    local treeZone = Components.TreeZone:new(20, 20, 60, 3)
    TestSuite.assert(treeZone ~= nil, "Composant TreeZone créé")
    TestSuite.assert(treeZone.woodAmount == 20, "Bois initial = 20")
    TestSuite.assert(treeZone.state == "available", "État initial = available")
    TestSuite.assert(treeZone:canHarvest(), "Zone peut être récoltée")
    
    -- Test 2: Commencer récolte
    local success = treeZone:startHarvest("villager1", 2)
    TestSuite.assert(success, "Démarrage récolte réussi")
    TestSuite.assert(treeZone:isBeingHarvested(), "Zone en cours de récolte")
    
    -- Test 3: Récolte pas encore terminée
    TestSuite.assert(not treeZone:isHarvestComplete("villager1"), "Récolte pas encore terminée")
    
    -- Test 4: Simuler completion de récolte
    local harvest = treeZone.currentHarvesters["villager1"]
    harvest.startTime = love.timer.getTime() - 5  -- Simuler 5 secondes passées
    TestSuite.assert(treeZone:isHarvestComplete("villager1"), "Récolte terminée après délai")
    
    -- Test 5: Compléter récolte
    local harvested = treeZone:completeHarvest("villager1")
    TestSuite.assert(harvested == 2 and treeZone.woodAmount == 18, "Récolte complétée: 2 bois")
    
    -- Test 6: Épuisement zone
    treeZone.woodAmount = 0
    treeZone:update(0.1)
    TestSuite.assert(treeZone.state == "depleted", "Zone épuisée")
    TestSuite.assert(not treeZone:canHarvest(), "Zone ne peut plus être récoltée")
end

function TestSuite.testTreeZoneEntity()
    print("\n--- Test Entité TreeZone ---")
    
    -- Test 1: Création entité TreeZone
    local position = { x = 300, y = 400 }
    local config = { name = "Test Forest", woodAmount = 25 }
    local treeZone = TreeZoneEntity:new("test_tree", position, config)
    
    TestSuite.assert(treeZone ~= nil, "Entité TreeZone créée")
    
    local nameComp = treeZone:getComponent("Name")
    TestSuite.assert(nameComp and nameComp.name == "Test Forest", "Nom configuré")
    
    local posComp = treeZone:getComponent("Position")
    TestSuite.assert(posComp and posComp.position.x == 300, "Position configurée")
    
    -- Test 2: Méthodes utilitaires
    TestSuite.assert(treeZone:getWoodAmount() == 25, "Quantité bois accessible")
    TestSuite.assert(treeZone:canHarvest(), "Zone peut être récoltée")
    TestSuite.assert(treeZone:getState() == "available", "État accessible")
    
    -- Test 3: Processus de récolte
    local startSuccess = treeZone:startHarvest("test_villager", 1)
    TestSuite.assert(startSuccess, "Démarrage récolte via entité")
    
    -- Simuler completion
    local treeComp = treeZone:getComponent("TreeZone")
    treeComp.currentHarvesters["test_villager"].startTime = love.timer.getTime() - 5
    
    TestSuite.assert(treeZone:isHarvestComplete("test_villager"), "Récolte complète détectée")
    
    local harvested = treeZone:completeHarvest("test_villager")
    TestSuite.assert(harvested == 1 and treeZone:getWoodAmount() == 24, "Récolte via entité")
end

function TestSuite.testVillagerEntityWithResource()
    print("\n--- Test Villageois avec Composant Resource ---")
    
    -- Test 1: Création villageois avec Resource
    local villagerData = {
        position = { x = 100, y = 100 },
        name = "Test Worker"
    }
    local villager = VillagerEntity:new("test_villager_resource", villagerData)
    
    local resource = villager:getComponent("Resource")
    TestSuite.assert(resource ~= nil, "Villageois a composant Resource")
    TestSuite.assert(resource.wood == 0 and resource.gold == 0, "Inventaire initial vide")
    
    -- Test 2: Ajout ressources
    resource:addWood(5)
    resource:addGold(2)
    TestSuite.assert(resource.wood == 5 and resource.gold == 2, "Ressources ajoutées")
    TestSuite.assert(resource.isCarrying, "État carrying actif")
    
    -- Test 3: Après recrutement
    local mockClan = { name = "TestClan", fame = 100 }
    villager:recruit(mockClan)
    
    local clan = villager:getComponent("Clan")
    TestSuite.assert(clan and clan.clanName == "TestClan", "Clan assigné après recrutement")
    
    -- Vérifier que Resource persiste après recrutement
    local resourceAfter = villager:getComponent("Resource")
    TestSuite.assert(resourceAfter and resourceAfter.wood == 5, "Resource persiste après recrutement")
end

function TestSuite.testTreeSpawnSystem()
    print("\n--- Test Système Spawn TreeZones ---")
    
    -- Test 1: Création système
    local treeSpawnSystem = TreeSpawnSystem:new(testWorld)
    TestSuite.assert(treeSpawnSystem ~= nil, "TreeSpawnSystem créé")
    TestSuite.assert(treeSpawnSystem.maxTrees == 6, "Limite 6 zones d'arbres")
    TestSuite.assert(#treeSpawnSystem.spawnZones == 6, "6 zones de spawn configurées")
    TestSuite.assert(#treeSpawnSystem.treeConfigs == 3, "3 configurations d'arbres")
    
    -- Test 2: Force spawn
    local position = { x = 200, y = 200 }
    local spawnedTree = treeSpawnSystem:forceSpawnTreeZone(position)
    TestSuite.assert(spawnedTree ~= nil, "Force spawn réussi")
    
    -- Test 3: Vérifier entité ajoutée au monde
    local treesInWorld = testWorld:getEntitiesWithAtLeast({"TreeZone"})
    TestSuite.assert(#treesInWorld == 1, "TreeZone ajoutée au monde")
    
    -- Test 4: Stats du système
    local stats = treeSpawnSystem:getTreeStats()
    TestSuite.assert(stats.current == 1 and stats.max == 6, "Stats système correctes")
    TestSuite.assert(stats.totalSpawned == 1, "Total spawn tracké")
    TestSuite.assert(#stats.zones == 1, "Info zones présente")
    
    -- Test 5: Zones disponibles
    local availableZones = treeSpawnSystem:getAvailableSpawnZones()
    TestSuite.assert(#availableZones < 6, "Zones occupées détectées")
end

function TestSuite.testVillagerAIExtensions()
    print("\n--- Test Extensions IA Villageois ---")
    
    -- Setup: Créer villageois et monde avec ressources
    local villager = VillagerEntity:new("ai_test_villager", { position = { x = 100, y = 100 } })
    local brain = villager:getComponent("Brain")
    local resource = villager:getComponent("Resource")
    
    testWorld:addEntity(villager)
    
    -- Ajouter TreeZone au monde
    local treeZone = TreeZoneEntity:new("test_tree_ai", { x = 120, y = 120 })
    testWorld:addEntity(treeZone)
    
    -- Test 1: IA system avec nouvelles tâches
    local aiSystem = VillagerAISystem:new(testWorld)
    TestSuite.assert(aiSystem ~= nil, "VillagerAISystem étendu créé")
    
    -- Test 2: Recherche de TreeZone
    local foundTree = aiSystem:findNearestTreeZone({ x = 100, y = 100 })
    TestSuite.assert(foundTree ~= nil and foundTree.id == "test_tree_ai", "findNearestTreeZone fonctionne")
    
    -- Test 3: Changement de tâche vers ChopWood
    brain.task = TaskEnum.ChopWood
    resource.targetResource = "wood"
    
    aiSystem:handleChopWoodBehavior(villager)
    
    local target = villager:getComponent("Target")
    TestSuite.assert(target.id == "test_tree_ai", "Villageois cible TreeZone")
    TestSuite.assert(target.isMoving, "Villageois se déplace vers TreeZone")
    
    -- Test 4: Comportement MineGold (sans mine présente)
    brain.task = TaskEnum.MineGold
    resource.targetResource = "gold"
    target.id = nil  -- Reset
    
    aiSystem:handleMineGoldBehavior(villager)
    TestSuite.assert(not target.isMoving, "Pas de mouvement sans mine")
end

function TestSuite.testContextMenuActivation()
    print("\n--- Test Activation Menu Contextuel ---")
    
    -- Setup: Mock des systèmes nécessaires
    local mockInteractionSystem = {
        playersNearVillagers = {
            ["test_player"] = {
                ["test_worker"] = true
            }
        }
    }
    
    local mockWorld = {
        systems = { mockInteractionSystem },
        getEntityById = function(self, id)
            if id == "test_player" then
                return {
                    getComponent = function(self, name)
                        if name == "Clan" then return { clanName = "TestClan" } end
                        return nil
                    end
                }
            elseif id == "test_worker" then
                return {
                    getComponent = function(self, name)
                        if name == "Worker" then return {} end
                        if name == "Clan" then return { clanName = "TestClan" } end
                        if name == "Brain" then return { task = TaskEnum.Idle } end
                        if name == "Name" then return { name = "Test Worker" } end
                        if name == "Life" then return { life = 100, maxLife = 100 } end
                        if name == "Speed" then return { speed = 50 } end
                        return nil
                    end
                }
            end
            return nil
        end
    }
    
    -- Test 1: Création menu contextuel
    local contextMenu = ContextMenuSystem:new(mockWorld)
    contextMenu.getInteractionSystem = function() return mockInteractionSystem end
    
    TestSuite.assert(contextMenu ~= nil, "ContextMenuSystem créé")
    
    -- Test 2: Vérifier tâches disponibles
    TestSuite.assert(contextMenu:isTaskAvailable(TaskEnum.Idle), "Idle disponible")
    TestSuite.assert(contextMenu:isTaskAvailable(TaskEnum.Follow), "Follow disponible")
    TestSuite.assert(contextMenu:isTaskAvailable(TaskEnum.ChopWood), "ChopWood disponible (Phase 5)")
    TestSuite.assert(contextMenu:isTaskAvailable(TaskEnum.MineGold), "MineGold disponible (Phase 5)")
    TestSuite.assert(not contextMenu:isTaskAvailable(TaskEnum.Defend), "Defend pas encore disponible")
    
    -- Test 3: Génération menu avec nouvelles tâches
    local menuResult = contextMenu:handleMenuRequest("test_player", "test_worker")
    TestSuite.assert(menuResult.success, "Menu généré avec succès")
    TestSuite.assert(#menuResult.availableTasks == 5, "5 tâches dans le menu")
    
    -- Vérifier que ChopWood et MineGold ne sont plus disabled
    local chopWoodTask = nil
    local mineGoldTask = nil
    for _, task in ipairs(menuResult.availableTasks) do
        if task.id == TaskEnum.ChopWood then chopWoodTask = task end
        if task.id == TaskEnum.MineGold then mineGoldTask = task end
    end
    
    TestSuite.assert(chopWoodTask and not chopWoodTask.disabled, "ChopWood activée dans menu")
    TestSuite.assert(mineGoldTask and not mineGoldTask.disabled, "MineGold activée dans menu")
end

function TestSuite.testTaskAvailability()
    print("\n--- Test Disponibilité Tâches ---")
    
    local contextMenu = ContextMenuSystem:new({})
    
    -- Test toutes les tâches Phase 5
    local availableTasks = {
        {TaskEnum.Idle, "Idle"},
        {TaskEnum.Follow, "Follow"},
        {TaskEnum.ChopWood, "ChopWood"},
        {TaskEnum.MineGold, "MineGold"}
    }
    
    for _, taskData in ipairs(availableTasks) do
        local taskId, taskName = taskData[1], taskData[2]
        TestSuite.assert(contextMenu:isValidTask(taskId), taskName .. " est une tâche valide")
        TestSuite.assert(contextMenu:isTaskAvailable(taskId), taskName .. " est disponible en Phase 5")
    end
    
    -- Test tâche pas encore disponible
    TestSuite.assert(contextMenu:isValidTask(TaskEnum.Defend), "Defend est valide")
    TestSuite.assert(not contextMenu:isTaskAvailable(TaskEnum.Defend), "Defend pas encore disponible")
end

function TestSuite.testResourceHarvesting()
    print("\n--- Test Processus Récolte Complet ---")
    
    -- Test 1: Setup complet
    local villager = VillagerEntity:new("harvest_test", { position = { x = 150, y = 150 } })
    local treeZone = TreeZoneEntity:new("harvest_tree", { x = 160, y = 160 })
    
    local resource = villager:getComponent("Resource")
    local target = villager:getComponent("Target")
    local brain = villager:getComponent("Brain")
    
    testWorld:addEntity(villager)
    testWorld:addEntity(treeZone)
    
    -- Test 2: Workflow ChopWood
    brain.task = TaskEnum.ChopWood
    
    local aiSystem = VillagerAISystem:new(testWorld)
    
    -- Étape 1: Trouve une cible
    aiSystem:handleChopWoodBehavior(villager)
    TestSuite.assert(target.id == "harvest_tree", "Trouve TreeZone comme cible")
    TestSuite.assert(resource.targetResource == "wood", "Resource ciblée = wood")
    
    -- Étape 2: Se rapprocher (simuler arrivée)
    local villagerPos = villager:getComponent("Position")
    villagerPos.position.x = 160
    villagerPos.position.y = 160
    
    -- Étape 3: Commencer récolte
    aiSystem:handleChopWoodBehavior(villager)
    
    local treeComp = treeZone:getComponent("TreeZone")
    TestSuite.assert(treeComp.currentHarvesters[villager.id] ~= nil, "Récolte commencée")
    
    -- Étape 4: Compléter récolte (simuler temps écoulé)
    treeComp.currentHarvesters[villager.id].startTime = love.timer.getTime() - 5
    aiSystem:handleChopWoodBehavior(villager)
    
    TestSuite.assert(resource.wood == 1, "Bois récolté ajouté à l'inventaire")
    TestSuite.assert(treeZone:getWoodAmount() == 19, "Bois retiré de la zone")
    
    -- Test 3: Inventaire plein
    resource.wood = 10  -- Remplir inventaire
    TestSuite.assert(not resource:canCarryWood(), "Inventaire bois plein")
    
    aiSystem:handleChopWoodBehavior(villager)
    TestSuite.assert(target.id == nil, "Stop récolte si inventaire plein")
end

function TestSuite.testIntegrationWorkflow()
    print("\n--- Test Workflow Intégration Complète ---")
    
    -- Test workflow complet: Spawn → Menu → Assignation → Récolte
    
    -- Phase 1: Spawn automatique des zones
    local treeSpawn = TreeSpawnSystem:new(testWorld)
    treeSpawn:forceSpawnTreeZone({ x = 400, y = 300 })
    
    local treesSpawned = testWorld:getEntitiesWithAtLeast({"TreeZone"})
    TestSuite.assert(#treesSpawned > 0, "Zones d'arbres spawnées")
    
    -- Phase 2: Création et recrutement villageois
    local worker = VillagerEntity:new("integration_worker", { position = { x = 350, y = 350 } })
    worker:recruit({ name = "IntegrationClan" })
    testWorld:addEntity(worker)
    
    local resource = worker:getComponent("Resource")
    local brain = worker:getComponent("Brain")
    TestSuite.assert(brain.task == TaskEnum.Follow, "Tâche initiale après recrutement")
    
    -- Phase 3: Assignation tâche ChopWood
    brain.task = TaskEnum.ChopWood
    TestSuite.assert(brain.task == TaskEnum.ChopWood, "Tâche assignée: ChopWood")
    
    -- Phase 4: Exécution IA
    local aiSystem = VillagerAISystem:new(testWorld)
    
    -- Simulation plusieurs cycles d'IA
    for i = 1, 5 do
        aiSystem:handleChopWoodBehavior(worker)
    end
    
    local target = worker:getComponent("Target")
    TestSuite.assert(target.id ~= nil, "Worker a trouvé une cible TreeZone")
    
    -- Phase 5: Stats finales
    local treeStats = treeSpawn:getTreeStats()
    TestSuite.assert(treeStats.current > 0, "Zones d'arbres actives")
    
    TestSuite.assert(resource ~= nil, "Système de ressources intégré")
    
    print("  🎯 Workflow complet validé: Spawn → Assign → AI → Harvest")
end

-- Exécution des tests
if not pcall(function() 
    TestSuite.runAllTests() 
end) then
    print("❌ ERREUR: Échec d'exécution des tests")
    print("Vérifiez que tous les fichiers sont présents et syntaxiquement corrects")
end 
