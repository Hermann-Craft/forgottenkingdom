local ContextMenuSystem = require(_G.libDir .. "middleclass")("ContextMenuSystem")
local System = require(_G.engineDir .. "system")
local TaskEnum = require(_G.gameDir .. "task-enum")

-- Hériter de System correctement
ContextMenuSystem.static.super = System

function ContextMenuSystem:initialize(world, debugMode)
    System.initialize(self, world)
    self.debugMode = debugMode or true -- Mode debug par défaut
    
    -- PLUS DE TIMEOUT AUTOMATIQUE - Les menus restent ouverts jusqu'à fermeture manuelle
    -- self.menuTimeouts = {} -- SUPPRIMÉ
    -- self.menuTimeoutDuration = 30 -- SUPPRIMÉ
    
    if self.debugMode then
        print("[CONTEXT-MENU] 🚀 Système de menu contextuel initialisé SANS timeout automatique")
        print("[CONTEXT-MENU] ⚠️ Les menus restent ouverts jusqu'à fermeture manuelle")
    end
end

function ContextMenuSystem:update(dt)
    -- PLUS DE TIMEOUT AUTOMATIQUE - rien à faire ici
    -- Les menus restent ouverts jusqu'à fermeture manuelle
end

function ContextMenuSystem:handleMenuRequest(playerId, villagerId)
    if self.debugMode then
        print("[CONTEXT-MENU] 📋 Demande de menu:", "Joueur", playerId, "→ Villageois", villagerId)
    end
    
    -- Étape 1: Vérifier que le joueur existe
    local player = self.world:getEntityById(playerId)
    if not player then
        if self.debugMode then
            print("[CONTEXT-MENU] ❌ Joueur", playerId, "non trouvé")
        end
        return {
            success = false,
            reason = "player_not_found",
            message = "Joueur introuvable!"
        }
    end
    
    -- Étape 2: Vérifier que le villageois existe et est un Worker
    local villager = self.world:getEntityById(villagerId)
    if not villager then
        if self.debugMode then
            print("[CONTEXT-MENU] ❌ Villageois", villagerId, "non trouvé")
        end
        return {
            success = false,
            reason = "villager_not_found",
            message = "Villageois introuvable!"
        }
    end
    
    -- Étape 3: Vérifier que c'est un Worker (recruté)
    local worker = villager:getComponent("Worker")
    if not worker then
        if self.debugMode then
            print("[CONTEXT-MENU] ❌ Villageois", villagerId, "n'est pas un Worker")
        end
        return {
            success = false,
            reason = "not_worker",
            message = "Ce villageois n'est pas recruté!"
        }
    end
    
    -- Étape 4: Vérifier que le joueur est propriétaire (même clan)
    local playerClan = player:getComponent("Clan")
    local villagerClan = villager:getComponent("Clan")
    
    if not playerClan or not villagerClan or playerClan.clanName ~= villagerClan.clanName then
        if self.debugMode then
            print("[CONTEXT-MENU] ❌ Joueur", playerId, "n'est pas propriétaire du villageois", villagerId)
        end
        return {
            success = false,
            reason = "not_owner",
            message = "Ce villageois n'appartient pas à votre clan!"
        }
    end
    
    -- Étape 5: Vérifier la proximité (utiliser le système d'interaction)
    local interactionSystem = self:getInteractionSystem()
    if not interactionSystem then
        return {
            success = false,
            reason = "system_error",
            message = "Erreur système!"
        }
    end
    
    -- Vérifier la proximité selon le type de système d'interaction
    local canInteract = false
    if interactionSystem.class.name == "InteractionOptimizedSystem" then
        -- Système optimisé : vérifier avec l'entité villager
        canInteract = interactionSystem:canPlayerInteractWithVillager(playerId, villager)
    else
        -- Système legacy : vérifier avec l'ID
        canInteract = interactionSystem:canPlayerInteractWithVillager(playerId, villagerId)
    end
    
    if not canInteract then
        if self.debugMode then
            print("[CONTEXT-MENU] ❌ Joueur", playerId, "trop loin du villageois", villagerId)
        end
        return {
            success = false,
            reason = "too_far",
            message = "Vous êtes trop loin du villageois!"
        }
    end
    
    -- Étape 6: Geler le villageois (ouvrir menu)
    local brain = villager:getComponent("Brain")
    brain.menuOpen = true  -- Geler le villageois
    
    if self.debugMode then
        print("[CONTEXT-MENU] 🔒 Villageois", villagerId, "gelé (menu ouvert) - AUCUN timeout automatique")
    end
    
    -- PLUS D'ENREGISTREMENT DE TIMEOUT - Le menu reste ouvert indéfiniment
    
    -- Étape 7: Construire les données du menu
    local villagerName = villager:getComponent("Name")
    
    local menuData = self:buildMenuData(villager, brain, villagerName)
    
    if self.debugMode then
        print("[CONTEXT-MENU] ✅ Menu généré pour villageois", villagerId)
        print("  - Tâche actuelle:", menuData.currentTask)
        print("  - Tâches disponibles:", #menuData.availableTasks)
    end
    
    return {
        success = true,
        villagerId = villagerId,
        villagerName = menuData.villagerName,
        currentTask = menuData.currentTask,
        availableTasks = menuData.availableTasks,
        villagerStats = menuData.stats
    }
end

function ContextMenuSystem:buildMenuData(villager, brain, villagerName)
    -- Tâche actuelle
    local currentTask = brain.task
    local currentTaskName = self:getTaskName(currentTask)
    
    -- Tâches disponibles (Phase 4 : toutes les tâches de base)
    local availableTasks = {
        {
            id = TaskEnum.Idle,
            name = "Repos",
            description = "Le villageois reste sur place",
            icon = "idle"
        },
        {
            id = TaskEnum.Follow,
            name = "Suivre",
            description = "Le villageois vous suit",
            icon = "follow"
        },
        {
            id = TaskEnum.ChopWood,
            name = "Couper du bois",
            description = "Récolte du bois automatiquement",
            icon = "wood"
            -- Phase 5: Maintenant disponible!
        },
        {
            id = TaskEnum.MineGold,
            name = "Miner l'or",
            description = "Récolte de l'or automatiquement",
            icon = "gold"
            -- Phase 5: Maintenant disponible!
        },
        {
            id = TaskEnum.Defend,
            name = "Défendre",
            description = "Protège la zone des ennemis",
            icon = "shield",
            disabled = true,  -- Phase 7
            disabledReason = "Disponible en Phase 7"
        }
    }
    
    -- Statistiques du villageois
    local life = villager:getComponent("Life")
    local speed = villager:getComponent("Speed")
    
    local stats = {
        life = life and life.life or 0,
        maxLife = life and life.maxLife or 0,
        speed = speed and speed.speed or 0
    }
    
    return {
        villagerName = villagerName and villagerName.name or "Villageois",
        currentTask = currentTaskName,
        availableTasks = availableTasks,
        stats = stats
    }
end

function ContextMenuSystem:handleTaskAssignment(playerId, villagerId, newTaskId)
    if self.debugMode then
        print("[CONTEXT-MENU] 🎯 Assignation tâche:", "Joueur", playerId, "→ Villageois", villagerId, "→ Tâche", newTaskId)
    end
    
    -- Reprendre les mêmes vérifications que pour le menu
    local result = self:handleMenuRequest(playerId, villagerId)
    if not result.success then
        return result  -- Retourner l'erreur de vérification
    end
    
    -- Vérifier que la tâche est valide
    if not self:isValidTask(newTaskId) then
        return {
            success = false,
            reason = "invalid_task",
            message = "Tâche invalide!"
        }
    end
    
    -- Vérifier que la tâche est disponible (pas disabled)
    if not self:isTaskAvailable(newTaskId) then
        return {
            success = false,
            reason = "task_disabled",
            message = "Cette tâche n'est pas encore disponible!"
        }
    end
    
    -- Obtenir le villageois et assigner la nouvelle tâche
    local villager = self.world:getEntityById(villagerId)
    local brain = villager:getComponent("Brain")
    local oldTask = brain.task
    
    brain.task = newTaskId
    
    -- Réinitialiser les cibles selon la nouvelle tâche
    local target = villager:getComponent("Target")
    if target then
        target.isMoving = false
        target.destination = nil
        target.distance = 0
        target.id = nil
    end
    
    -- Dégeler le villageois (fermer menu)
    brain.menuOpen = false
    
    -- PLUS DE TIMEOUT - supprimé
    
    if self.debugMode then
        print("[CONTEXT-MENU] ✅ Tâche changée:", self:getTaskName(oldTask), "→", self:getTaskName(newTaskId))
        print("[CONTEXT-MENU] 🔓 Villageois", villagerId, "dégelé (menu fermé)")
    end
    
    return {
        success = true,
        villagerId = villagerId,
        oldTask = self:getTaskName(oldTask),
        newTask = self:getTaskName(newTaskId),
        message = "Tâche assignée avec succès!"
    }
end

-- NOUVEAU: Méthode pour gérer la fermeture explicite d'un menu
function ContextMenuSystem:handleMenuClose(playerId, villagerId)
    if self.debugMode then
        print("[CONTEXT-MENU] 🚪 Demande fermeture menu:", playerId, "→", villagerId)
    end
    
    -- Vérifications de base
    local villager = self.world:getEntityById(villagerId)
    if not villager then
        return {
            success = false,
            reason = "villager_not_found",
            message = "Villageois introuvable!"
        }
    end
    
    local brain = villager:getComponent("Brain")
    if not brain then
        return {
            success = false,
            reason = "no_brain",
            message = "Erreur villageois!"
        }
    end
    
    -- Fermer le menu si ouvert
    if brain.menuOpen then
        brain.menuOpen = false
        -- PLUS DE TIMEOUT - supprimé
        
        if self.debugMode then
            print("[CONTEXT-MENU] ✅ Menu fermé manuellement pour villageois", villagerId)
        end
    end
    
    return {
        success = true,
        villagerId = villagerId
    }
end

function ContextMenuSystem:getTaskName(taskId)
    local taskNames = {
        [TaskEnum.Idle] = "Repos",
        [TaskEnum.Follow] = "Suivre",
        [TaskEnum.ChopWood] = "Couper du bois",
        [TaskEnum.MineGold] = "Miner l'or",
        [TaskEnum.Defend] = "Défendre"
    }
    return taskNames[taskId] or "Inconnu"
end

function ContextMenuSystem:isValidTask(taskId)
    return taskId == TaskEnum.Idle or 
           taskId == TaskEnum.Follow or
           taskId == TaskEnum.ChopWood or
           taskId == TaskEnum.MineGold or
           taskId == TaskEnum.Defend
end

function ContextMenuSystem:isTaskAvailable(taskId)
    -- Phase 5 : Idle, Follow, ChopWood et MineGold sont disponibles
    return taskId == TaskEnum.Idle or 
           taskId == TaskEnum.Follow or
           taskId == TaskEnum.ChopWood or
           taskId == TaskEnum.MineGold
end

function ContextMenuSystem:getInteractionSystem()
    -- Trouver le système d'interaction dans le monde (optimisé ou legacy)
    for _, system in ipairs(self.world.systems) do
        if system.class.name == "InteractionOptimizedSystem" or system.class.name == "InteractionSystem" then
            return system
        end
    end
    return nil
end

-- Méthode pour fermer explicitement le menu sans assigner de tâche
function ContextMenuSystem:closeMenu(playerId, villagerId)
    if self.debugMode then
        print("[CONTEXT-MENU] 🚪 Fermeture menu:", "Joueur", playerId, "→ Villageois", villagerId)
    end
    
    -- Vérifier que le villageois existe
    local villager = self.world:getEntityById(villagerId)
    if not villager then
        return {
            success = false,
            reason = "villager_not_found",
            message = "Villageois introuvable!"
        }
    end
    
    -- Dégeler le villageois
    local brain = villager:getComponent("Brain")
    if brain then
        brain.menuOpen = false
        
        if self.debugMode then
            print("[CONTEXT-MENU] 🔓 Villageois", villagerId, "dégelé (menu fermé)")
        end
    end
    
    return {
        success = true,
        villagerId = villagerId,
        message = "Menu fermé"
    }
end

-- Méthode utilitaire pour obtenir les statistiques des menus
function ContextMenuSystem:getMenuStats()
    local workers = self.world:getEntitiesWithAtLeast({"Villager", "Worker"})
    
    local taskCounts = {}
    for _, worker in ipairs(workers) do
        local brain = worker:getComponent("Brain")
        if brain then
            taskCounts[brain.task] = (taskCounts[brain.task] or 0) + 1
        end
    end
    
    return {
        totalWorkers = #workers,
        taskBreakdown = taskCounts
    }
end

return ContextMenuSystem 
