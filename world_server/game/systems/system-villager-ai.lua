local VillagerAISystem = require(_G.libDir .. "middleclass")("VillagerAISystem")
local System = require(_G.engineDir .. "system")
VillagerAISystem.static.super = System

local TaskEnum = require(_G.gameDir .. "task-enum")
local Compositions = require(_G.gameDir .. "compositions")

function VillagerAISystem:initialize(world, debugMode)
    System.initialize(self, world)
    
    -- Configuration de base
    self.debugMode = debugMode or false
    self.updateFrequency = 2.0 -- OPTIMISATION: Ralentir à 2 secondes au lieu de 0.5
    self.updateTimer = 0
    
    -- Timers pour les logs optimisés
    self.logTimer = 0
    self.detailedLogTimer = 0
    
    -- Paramètres de mouvement
    self.IDLE_MOVE_SPEED = 30      -- Vitesse de déplacement libre
    self.WORK_MOVE_SPEED = 50      -- Vitesse de déplacement au travail
    self.FOLLOW_MOVE_SPEED = 70    -- Vitesse de suivi du maître
    
    -- Paramètres de comportement
    self.FOLLOW_DISTANCE = 100     -- Distance de suivi du maître
    self.WORK_RANGE = 150          -- Portée de recherche de travail
    self.IDLE_CHANGE_TIME = 3.0    -- Temps entre changements de direction
    
    -- Statistiques (pour monitoring)
    self.totalVillagers = 0
    self.activeWorkers = 0
    self.idleVillagers = 0
    
    print("[VILLAGER AI] Système initialisé avec mode debug:", self.debugMode and "ACTIVÉ" or "DÉSACTIVÉ")
    print("[VILLAGER AI] Fréquence de mise à jour:", self.updateFrequency, "secondes")
end

function VillagerAISystem:update(dt)
    self.updateTimer = self.updateTimer + dt
    
    -- OPTIMISATION: Réduire la fréquence des logs et des calculs
    if self.updateTimer >= self.updateFrequency then
        self.updateTimer = 0
        
        -- Obtenir tous les villageois avec IA
        local villagers = self.world:getEntitiesWithAtLeast({"Villager", "Position", "Target", "Speed", "Brain"})
        
        -- OPTIMISATION: Logs réduits - seulement événements importants
        if self.debugMode and #villagers > 0 then
            -- Log seulement toutes les 5 secondes au lieu de chaque update
            self.logTimer = (self.logTimer or 0) + self.updateFrequency
            if self.logTimer >= 5.0 then
                print("[VILLAGER AI] Mise à jour IA pour", #villagers, "villageois")
                self.logTimer = 0
            end
        end
        
        -- Traitement de l'IA
        for _, villager in ipairs(villagers) do
            self:processVillagerAI(villager)
        end
    end
    
    -- Mise à jour du mouvement continue (pour la fluidité)
    self:updateMovement(dt)
end

-- Remplacer l'ancienne méthode updateVillagerAI par une version optimisée
function VillagerAISystem:updateVillagerAI()
    -- Cette méthode est maintenant obsolète, remplacée par update() optimisé
    -- Rediriger vers la nouvelle logique
    local villagers = self.world:getEntitiesWithAtLeast({"Villager", "Position", "Target", "Speed", "Brain"})
    
    for _, villager in ipairs(villagers) do
        self:processVillagerAI(villager)
    end
end

function VillagerAISystem:processVillagerAI(villager)
    local brain = villager:getComponent("Brain")
    local position = villager:getComponent("Position")
    local target = villager:getComponent("Target")
    local speed = villager:getComponent("Speed")
    
    -- Ne pas traiter si le menu est ouvert
    if brain.menuOpen then
        return
    end
    
    -- Logique d'IA selon l'état
    if brain.state == "idle" then
        if not target.isMoving then
            -- Générer une nouvelle destination aléatoire
            local newX = love.math.random(50, self.world.width - 50)
            local newY = love.math.random(50, self.world.height - 50)
            
            target.destination = { x = newX, y = newY }
            target.isMoving = true
            
            -- OPTIMISATION: Logs réduits - seulement pour debug détaillé
            if self.debugMode and (self.detailedLogTimer or 0) > 10 then
                print("[VILLAGER AI]", villager.id, "nouvelle destination:", newX, newY)
                self.detailedLogTimer = 0
            end
            self.detailedLogTimer = (self.detailedLogTimer or 0) + self.updateFrequency
        end
    elseif brain.state == "working" then
        -- Logique de travail (récolte, etc.)
        self:processWorkingBehavior(villager)
    elseif brain.state == "following" then
        -- Logique de suivi
        self:processFollowingBehavior(villager)
    end
end

function VillagerAISystem:handleIdleBehavior(villager)
    -- Comportement aléatoire pour villageois inactifs
    if love.math.random() < self.IDLE_MOVE_CHANCE then
        local position = villager:getComponent("Position")
        local target = villager:getComponent("Target")
        
        if position then
            -- Générer une nouvelle destination aléatoire
            local newTarget = self:generateRandomDestination(position.position)
            
            -- Mettre à jour la cible
            if target then
                target.destination = newTarget
                target.isMoving = true
            end
            
            -- Debug très réduit: seulement occasionnellement
            if self.debugMode and love.math.random() < 0.1 then
                print("[VILLAGER AI] 🚶", villager.id, "nouvelle destination")
            end
        end
    end
end

function VillagerAISystem:handleFollowBehavior(villager)
    -- Phase 4: Implémentation du comportement de suivi
    local clan = villager:getComponent("Clan")
    if not clan then
        if self.debugMode then
            print("[VILLAGER AI] ❌ Villageois", villager.id, "en mode Follow mais sans clan")
        end
        return
    end
    
    -- Trouver le maître (joueur du même clan)
    local master = self:findClanMaster(clan.clanName)
    if not master then
        if self.debugMode then
            print("[VILLAGER AI] ⚠️ Maître introuvable pour", villager.id, "clan:", clan.clanName)
        end
        -- Pas de maître trouvé, rester immobile
        local target = villager:getComponent("Target")
        if target then
            target.isMoving = false
        end
        return
    end
    
    local villagerPos = villager:getComponent("Position")
    local masterPos = master:getComponent("Position")
    local target = villager:getComponent("Target")
    
    if not villagerPos or not masterPos or not target then
        return
    end
    
    -- Calculer la distance au maître
    local dx = masterPos.position.x - villagerPos.position.x
    local dy = masterPos.position.y - villagerPos.position.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Configuration du comportement de suivi
    local FOLLOW_DISTANCE = 60  -- Distance minimale avant de commencer à suivre
    local CLOSE_DISTANCE = 30   -- Distance à laquelle arrêter de se rapprocher
    
    if distance > FOLLOW_DISTANCE then
        -- Trop loin, se diriger vers le maître
        local followTarget = {
            x = masterPos.position.x + love.math.random(-CLOSE_DISTANCE, CLOSE_DISTANCE),
            y = masterPos.position.y + love.math.random(-CLOSE_DISTANCE, CLOSE_DISTANCE)
        }
        
        target.destination = followTarget
        target.isMoving = true
        target.id = master.id  -- Référence au maître
        
        if self.debugMode then
            print("[VILLAGER AI] 🚶 Villageois", villager.id, "suit maître", master.id, "- distance:", math.floor(distance))
        end
    elseif distance <= CLOSE_DISTANCE then
        -- Assez proche, arrêter de bouger
        target.isMoving = false
        target.destination = nil
        
        if self.debugMode then
            print("[VILLAGER AI] ✋ Villageois", villager.id, "proche du maître - arrêt")
        end
    end
    -- Entre CLOSE_DISTANCE et FOLLOW_DISTANCE : continuer le mouvement actuel
end

function VillagerAISystem:generateRandomDestination(currentPos)
    local angle = love.math.random() * 2 * math.pi
    local distance = love.math.random() * self.IDLE_MOVE_DISTANCE
    
    local newX = currentPos.x + math.cos(angle) * distance
    local newY = currentPos.y + math.sin(angle) * distance
    
    -- S'assurer que la destination est dans les limites du monde
    newX = math.max(self.worldBounds.minX, math.min(self.worldBounds.maxX, newX))
    newY = math.max(self.worldBounds.minY, math.min(self.worldBounds.maxY, newY))
    
    return { x = newX, y = newY }
end

function VillagerAISystem:updateMovement(dt)
    -- OPTIMISATION: Mettre à jour seulement les villageois en mouvement
    local movingVillagers = self.world:getEntitiesWithAtLeast({"Villager", "Position", "Target", "Speed", "Brain"})
    
    local actuallyMoving = 0
    
    for _, villager in ipairs(movingVillagers) do
        local brain = villager:getComponent("Brain")
        local position = villager:getComponent("Position")
        local target = villager:getComponent("Target")
        local speed = villager:getComponent("Speed")
        local orientation = villager:getComponent("Orientation")
        
        -- Ne pas bouger si le menu est ouvert
        if brain.menuOpen then
            target.isMoving = false
            goto continue_movement
        end
        
        -- OPTIMISATION: Ne traiter que les villageois réellement en mouvement
        if target.isMoving and target.destination then
            actuallyMoving = actuallyMoving + 1
            
            -- Calculer la direction vers la destination
            local dx = target.destination.x - position.position.x
            local dy = target.destination.y - position.position.y
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance > 5 then  -- Seuil d'arrivée
                -- Normaliser la direction et appliquer la vitesse
                local dirX = dx / distance
                local dirY = dy / distance
                
                local moveSpeed = speed.speed or self.IDLE_MOVE_SPEED
                position.position.x = position.position.x + dirX * moveSpeed * dt
                position.position.y = position.position.y + dirY * moveSpeed * dt
                
                -- Mettre à jour l'orientation seulement si nécessaire
                if orientation and (math.abs(dx) > 1 or math.abs(dy) > 1) then
                    orientation.orientation = math.atan2(dy, dx)
                end
                
                -- Mettre à jour la distance restante
                target.distance = distance
            else
                -- Arrivé à destination
                target.isMoving = false
                target.destination = nil
                target.distance = 0
                
                -- OPTIMISATION: Log d'arrivée seulement si debug détaillé activé
                if self.debugMode and (self.detailedLogTimer or 0) > 10 then
                    print("[VILLAGER AI]", villager.id, "arrivé à destination")
                end
            end
        end
        
        ::continue_movement::
    end
    
    -- Statistiques pour monitoring (mise à jour toutes les 5 secondes)
    if self.debugMode then
        self.movementLogTimer = (self.movementLogTimer or 0) + dt
        if self.movementLogTimer > 5.0 then
            print("[VILLAGER AI] Villageois en mouvement:", actuallyMoving, "/", #movingVillagers)
            self.movementLogTimer = 0
        end
    end
end

-- Phase 4: Méthode pour trouver le maître d'un clan (joueur)
function VillagerAISystem:findClanMaster(clanName)
    -- Obtenir tous les joueurs
    local players = self.world:getEntitiesWithStrict(Compositions.Player)
    
    for _, player in ipairs(players) do
        local playerClan = player:getComponent("Clan")
        if playerClan and playerClan.clanName == clanName then
            return player
        end
    end
    
    return nil  -- Aucun maître trouvé
end

-- Phase 5: Comportement de récolte de bois
function VillagerAISystem:handleChopWoodBehavior(villager)
    local target = villager:getComponent("Target")
    local position = villager:getComponent("Position")
    local resource = villager:getComponent("Resource")
    
    if not target or not position or not resource then
        return
    end
    
    -- Phase 1: Chercher une zone d'arbres si pas de cible
    if not target.id then
        local treeZone = self:findNearestTreeZone(position.position)
        if treeZone then
            target.id = treeZone.id
            target.destination = treeZone:getComponent("Position").position
            target.isMoving = true
            resource.targetResource = "wood"
            
            if self.debugMode then
                print("[VILLAGER AI] 🌲", villager.id, "cible zone d'arbres:", treeZone.id)
            end
        else
            -- Pas de zone d'arbres disponible, rester immobile
            target.isMoving = false
            if self.debugMode then
                print("[VILLAGER AI] ⚠️", villager.id, "aucune zone d'arbres disponible")
            end
        end
        return
    end
    
    -- Phase 2: Se diriger vers la zone d'arbres
    local treeZone = self.world:getEntityById(target.id)
    if not treeZone then
        -- Zone d'arbres disparue, chercher une nouvelle
        target.id = nil
        return
    end
    
    local treePos = treeZone:getComponent("Position")
    if not target.destination and treePos then
        target.destination = treePos.position
        target.isMoving = true
    end
    
    -- Phase 3: Vérifier si proche de la zone d'arbres
    if treePos then
        local distance = math.sqrt((position.position.x - treePos.position.x)^2 + 
                                 (position.position.y - treePos.position.y)^2)
        
        if distance <= 50 then  -- À portée de récolte
            target.isMoving = false
            
            -- Phase 4: Commencer/continuer la récolte
            local treeComponent = treeZone:getComponent("TreeZone")
            if treeComponent and treeComponent:canHarvest() and resource:canCarryWood() then
                
                -- Commencer la récolte si pas déjà en cours
                if not treeComponent.currentHarvesters[villager.id] then
                    local success = treeComponent:startHarvest(villager.id, 1)
                    if success and self.debugMode then
                        print("[VILLAGER AI] 🪓", villager.id, "commence récolte bois")
                    end
                end
                
                -- Vérifier si récolte terminée
                if treeComponent:isHarvestComplete(villager.id) then
                    local harvested = treeComponent:completeHarvest(villager.id)
                    resource:addWood(harvested)
                    
                    if self.debugMode then
                        print("[VILLAGER AI] ✅", villager.id, "récolte", harvested, "bois - total:", resource.wood)
                    end
                    
                    -- Vérifier si inventaire plein ou si zone épuisée
                    if not resource:canCarryWood() or not treeComponent:canHarvest() then
                        -- Chercher une nouvelle zone ou retourner au maître
                        target.id = nil
                        target.destination = nil
                        
                        if self.debugMode then
                            local reason = not resource:canCarryWood() and "inventaire plein" or "zone épuisée"
                            print("[VILLAGER AI] 📦", villager.id, "arrêt récolte:", reason)
                        end
                    end
                end
            else
                -- Zone non disponible, chercher une nouvelle
                target.id = nil
                target.destination = nil
            end
        end
    end
end

-- Phase 5: Comportement de minage d'or
function VillagerAISystem:handleMineGoldBehavior(villager)
    local target = villager:getComponent("Target")
    local position = villager:getComponent("Position")
    local resource = villager:getComponent("Resource")
    
    if not target or not position or not resource then
        return
    end
    
    -- Phase 1: Chercher une mine si pas de cible
    if not target.id then
        local mine = self:findNearestMine(position.position)
        if mine then
            target.id = mine.id
            target.destination = mine:getComponent("Position").position
            target.isMoving = true
            resource.targetResource = "gold"
            
            if self.debugMode then
                print("[VILLAGER AI] ⛏️", villager.id, "cible mine:", mine.id)
            end
        else
            -- Pas de mine disponible, rester immobile
            target.isMoving = false
            if self.debugMode then
                print("[VILLAGER AI] ⚠️", villager.id, "aucune mine disponible")
            end
        end
        return
    end
    
    -- Phase 2: Se diriger vers la mine
    local mine = self.world:getEntityById(target.id)
    if not mine then
        -- Mine disparue, chercher une nouvelle
        target.id = nil
        return
    end
    
    local minePos = mine:getComponent("Position")
    if not target.destination and minePos then
        target.destination = minePos.position
        target.isMoving = true
    end
    
    -- Phase 3: Vérifier si proche de la mine
    if minePos then
        local distance = math.sqrt((position.position.x - minePos.position.x)^2 + 
                                 (position.position.y - minePos.position.y)^2)
        
        if distance <= 60 then  -- À portée de minage
            target.isMoving = false
            
            -- Phase 4: Simuler le minage (utiliser système existant comme référence)
            local mineComponent = mine:getComponent("Resources")
            if mineComponent and mineComponent.state == "available" and 
               mineComponent.goldAmount > 0 and resource:canCarryGold() then
                
                -- Timer de minage (2 secondes par or)
                if not villager._miningTimer then
                    villager._miningTimer = 2.0  -- 2 secondes pour miner 1 or
                    if self.debugMode then
                        print("[VILLAGER AI] ⛏️", villager.id, "commence minage or")
                    end
                end
                
                villager._miningTimer = villager._miningTimer - (1/60)  -- Approximation 60 FPS
                
                if villager._miningTimer <= 0 then
                    -- Minage terminé
                    local mined = math.min(1, mineComponent.goldAmount)
                    mineComponent.goldAmount = mineComponent.goldAmount - mined
                    resource:addGold(mined)
                    villager._miningTimer = nil
                    
                    if self.debugMode then
                        print("[VILLAGER AI] ✅", villager.id, "mine", mined, "or - total:", resource.gold)
                    end
                    
                    -- Vérifier si inventaire plein ou mine épuisée
                    if not resource:canCarryGold() or mineComponent.goldAmount <= 0 then
                        -- Chercher une nouvelle mine ou retourner au maître
                        target.id = nil
                        target.destination = nil
                        
                        if mineComponent.goldAmount <= 0 then
                            mineComponent.state = "depleted"
                            mineComponent.respawnTimer = mineComponent.respawnTime or 30
                        end
                        
                        if self.debugMode then
                            local reason = not resource:canCarryGold() and "inventaire plein" or "mine épuisée"
                            print("[VILLAGER AI] 📦", villager.id, "arrêt minage:", reason)
                        end
                    end
                end
            else
                -- Mine non disponible, chercher une nouvelle
                target.id = nil
                target.destination = nil
                villager._miningTimer = nil
            end
        end
    end
end

-- Méthodes utilitaires pour la recherche de ressources
function VillagerAISystem:findNearestTreeZone(position)
    local treeZones = self.world:getEntitiesWithAtLeast({"TreeZone"})
    local nearestZone = nil
    local minDistance = math.huge
    
    for _, zone in ipairs(treeZones) do
        local treeComponent = zone:getComponent("TreeZone")
        local zonePos = zone:getComponent("Position")
        
        if treeComponent and treeComponent:canHarvest() and zonePos then
            local distance = math.sqrt((position.x - zonePos.position.x)^2 + 
                                     (position.y - zonePos.position.y)^2)
            
            if distance < minDistance then
                minDistance = distance
                nearestZone = zone
            end
        end
    end
    
    return nearestZone
end

function VillagerAISystem:findNearestMine(position)
    local mines = self.world:getEntitiesWithAtLeast({"Resources"})
    local nearestMine = nil
    local minDistance = math.huge
    
    for _, mine in ipairs(mines) do
        local mineComponent = mine:getComponent("Resources")
        local minePos = mine:getComponent("Position")
        
        if mineComponent and mineComponent.state == "available" and 
           mineComponent.goldAmount > 0 and minePos then
            local distance = math.sqrt((position.x - minePos.position.x)^2 + 
                                     (position.y - minePos.position.y)^2)
            
            if distance < minDistance then
                minDistance = distance
                nearestMine = mine
            end
        end
    end
    
    return nearestMine
end

-- Méthode utilitaire pour changer la tâche d'un villageois
function VillagerAISystem:setVillagerTask(villagerId, newTask)
    local villager = self.world:getEntityById(villagerId)
    if villager then
        local brain = villager:getComponent("Brain")
        if brain then
            brain.task = newTask
            
            -- Réinitialiser les cibles selon la nouvelle tâche
            local target = villager:getComponent("Target")
            if target then
                target.isMoving = false
                target.destination = nil
                target.distance = 0
                target.id = nil
            end
            
            -- Réinitialiser les timers de minage
            villager._miningTimer = nil
            
            -- Réinitialiser les ressources ciblées
            local resource = villager:getComponent("Resource")
            if resource then
                resource.targetResource = nil
            end
            
            if self.debugMode then
                print("[VILLAGER AI]", villagerId, "nouvelle tâche:", newTask)
            end
            return true
        end
    end
    return false
end

return VillagerAISystem 
