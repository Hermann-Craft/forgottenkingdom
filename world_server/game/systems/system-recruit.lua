local RecruitSystem = require(_G.libDir .. "middleclass")("RecruitSystem")
local System = require(_G.engineDir .. "system")
RecruitSystem.static.super = System

local TaskEnum = require(_G.gameDir .. "task-enum")
local Compositions = require(_G.gameDir .. "compositions")

function RecruitSystem:initialize(world, debugMode)
    System.initialize(self, world)
    self.debugMode = debugMode or false
    
    -- Configuration du recrutement
    self.RECRUITMENT_COST = 25  -- Coût en or pour recruter un villageois
    
    if self.debugMode then
        print("[RECRUIT] Système de recrutement initialisé - Coût:", self.RECRUITMENT_COST, "or")
    end
end

function RecruitSystem:update(dt)
    -- Ce système ne fait rien en update, il réagit aux messages réseau
end

function RecruitSystem:handleRecruitmentRequest(playerId, villagerId)
    -- Force le debug pour ce test
    local originalDebug = self.debugMode
    self.debugMode = true
    
    print("[RECRUIT] 📨 === DÉBUT RECRUTEMENT ===")
    print("[RECRUIT] Demande de recrutement:", "Joueur", playerId, "→ Villageois", villagerId)
    print("[RECRUIT] Mode debug activé:", self.debugMode)
    
    -- Étape 1: Vérifier que le joueur existe et est connecté
    local player = self.world:getEntityById(playerId)
    if not player then
        if self.debugMode then
            print("[RECRUIT] ❌ Joueur", playerId, "non trouvé")
        end
        self.debugMode = originalDebug
        print("[RECRUIT] 📨 === FIN RECRUTEMENT (joueur non trouvé) ===")
        return {
            success = false,
            reason = "player_not_found",
            message = "Joueur introuvable!"
        }
    end
    
    -- Étape 2: Vérifier que le villageois existe et est recrutables
    local villager = self.world:getEntityById(villagerId)
    if not villager then
        if self.debugMode then
            print("[RECRUIT] ❌ Villageois", villagerId, "non trouvé")
        end
        return {
            success = false,
            reason = "villager_not_found",
            message = "Villageois introuvable!"
        }
    end
    
    -- Étape 3: Vérifier que le villageois est toujours recrutables (tag Hireable)
    local hireable = villager:getComponent("Hireable")
    if not hireable then
        if self.debugMode then
            print("[RECRUIT] ❌ Villageois", villagerId, "n'est plus recrutables")
        end
        return {
            success = false,
            reason = "not_hireable",
            message = "Ce villageois n'est plus disponible!"
        }
    end
    
        -- Étape 4: Vérifier la proximité (déléguer au système d'interaction)
    local interactionSystem = self:getInteractionSystem()
    if not interactionSystem then
        return {
            success = false,
            reason = "system_error",
            message = "Erreur système!"
        }
    end

    -- Forcer le debug sur le système d'interaction temporairement
    local interactionOriginalDebug = interactionSystem.debugMode
    interactionSystem.debugMode = true
    
    -- Vérifier la proximité avec système de grâce selon le type de système
    print("[RECRUIT] 🔍 Appel à canPlayerInteractWithVillager...")
    local canInteract = false
    
    if interactionSystem.class.name == "InteractionOptimizedSystem" then
        -- Système optimisé : passer l'entité villager
        canInteract = interactionSystem:canPlayerInteractWithVillager(playerId, villager)
        print("[RECRUIT] 🔍 Système optimisé utilisé")
    else
        -- Système legacy : passer l'ID du villager
        canInteract = interactionSystem:canPlayerInteractWithVillager(playerId, villagerId)
        print("[RECRUIT] 🔍 Système legacy utilisé")
    end
    
    print("[RECRUIT] 🔍 Retour de canPlayerInteractWithVillager:", canInteract)
    
    -- Restaurer le debug du système d'interaction
    interactionSystem.debugMode = interactionOriginalDebug
    
    if self.debugMode then
        print("[RECRUIT] 🔍 Vérification proximité pour joueur", playerId, "→ villageois", villagerId)
        print("[RECRUIT] Résultat interaction:", canInteract and "AUTORISÉE" or "REFUSÉE")
    end

    if not canInteract then
        if self.debugMode then
            print("[RECRUIT] ❌ Joueur", playerId, "ne peut pas interagir avec villageois", villagerId)
            -- Calculer la distance réelle pour debug (seulement pour système legacy)
            if interactionSystem.class.name ~= "InteractionOptimizedSystem" then
                local playerPos = player:getComponent("Position")
                local villagerPos = villager:getComponent("Position")
                local villagerDim = villager:getComponent("Dimension")
                if playerPos and villagerPos and villagerDim then
                    local distance = interactionSystem:calculateDistanceVillager(playerPos.position, villagerPos.position, villagerDim)
                    print("[RECRUIT] Distance réelle calculée:", distance, "pixels (seuil:", interactionSystem.villagerInteractionDistance, ")")
                end
            else
                print("[RECRUIT] Distance non calculée (système optimisé utilise sa propre logique)")
            end
        end
        return {
            success = false,
            reason = "too_far",
            message = "Vous êtes trop loin du villageois!"
        }
    end
    
    -- Étape 5: Vérifier le portefeuille du joueur
    local playerWallet = player:getComponent("Wallet")
    if not playerWallet then
        return {
            success = false,
            reason = "no_wallet",
            message = "Portefeuille introuvable!"
        }
    end
    
    if playerWallet.wallet < self.RECRUITMENT_COST then
        if self.debugMode then
            print("[RECRUIT] ❌ Joueur", playerId, "n'a pas assez d'or:", playerWallet.wallet, "/", self.RECRUITMENT_COST)
        end
        return {
            success = false,
            reason = "insufficient_gold",
            message = "Pas assez d'or! Vous avez " .. playerWallet.wallet .. " or, il faut " .. self.RECRUITMENT_COST .. " or."
        }
    end
    
    -- Étape 6: Obtenir le clan du joueur
    local playerClan = player:getComponent("Clan")
    if not playerClan then
        if self.debugMode then
            print("[RECRUIT] ❌ Joueur", playerId, "n'a pas de clan")
        end
        return {
            success = false,
            reason = "no_clan",
            message = "Vous devez appartenir à un clan pour recruter!"
        }
    end
    
    -- Étape 7: Effectuer le recrutement
    local success, errorMsg = self:performRecruitment(player, villager, playerClan)
    
    local result
    if success then
        if self.debugMode then
            print("[RECRUIT] ✅ Recrutement réussi:", villagerId, "rejoint le clan", playerClan.clanName)
        end
        
        result = {
            success = true,
            villagerId = villagerId,
            villagerName = villager:getComponent("Name").name,
            goldSpent = self.RECRUITMENT_COST,
            newGoldTotal = playerWallet.wallet,
            clanName = playerClan.clanName
        }
    else
        if self.debugMode then
            print("[RECRUIT] ❌ Échec recrutement:", errorMsg)
        end
        
        result = {
            success = false,
            reason = "recruitment_failed",
            message = errorMsg or "Échec du recrutement!"
        }
    end
    
    -- Restaurer le debug original
    self.debugMode = originalDebug
    print("[RECRUIT] 📨 === FIN RECRUTEMENT ===")
    
    return result
end

function RecruitSystem:performRecruitment(player, villager, playerClan)
    -- Déduire l'or du joueur
    local playerWallet = player:getComponent("Wallet")
    playerWallet.wallet = playerWallet.wallet - self.RECRUITMENT_COST
    
    -- Recruter le villageois (utiliser la méthode de l'entité)
    local success, errorMsg = pcall(function()
        villager:recruit({
            name = playerClan.clanName,
            fame = playerClan.clanFame or 0
        })
    end)
    
    if not success then
        -- Rembourser le joueur en cas d'erreur
        playerWallet.wallet = playerWallet.wallet + self.RECRUITMENT_COST
        return false, "Erreur lors du recrutement: " .. tostring(errorMsg)
    end
    
    return true
end

function RecruitSystem:getInteractionSystem()
    -- Debug: lister tous les systèmes disponibles
    if self.debugMode then
        print("[RECRUIT] 🔍 Systèmes disponibles dans le monde:")
        for i, system in ipairs(self.world.systems) do
            local systemName = system.class and system.class.name or "Système sans nom"
            print("  -", i, ":", systemName, ":", tostring(system))
        end
    end
    
    -- Trouver le système d'interaction dans le monde (optimisé ou legacy)
    for _, system in ipairs(self.world.systems) do
        if system.class then
            local className = system.class.name
            if className == "InteractionOptimizedSystem" or className == "InteractionSystem" then
                if self.debugMode then
                    print("[RECRUIT] ✅ Système d'interaction trouvé (" .. className .. "):", tostring(system))
                end
                return system
            end
        end
    end
    
    if self.debugMode then
        print("[RECRUIT] ❌ Système d'interaction NON TROUVÉ!")
    end
    return nil
end

-- Méthode utilitaire pour obtenir les statistiques de recrutement
function RecruitSystem:getRecruitmentStats()
    local hireableVillagers = self.world:getEntitiesWithAtLeast({"Villager", "Hireable"})
    local workers = self.world:getEntitiesWithAtLeast({"Villager", "Worker"})
    
    local clans = {}
    for _, worker in ipairs(workers) do
        local clan = worker:getComponent("Clan")
        if clan then
            clans[clan.clanName] = (clans[clan.clanName] or 0) + 1
        end
    end
    
    return {
        available = #hireableVillagers,
        recruited = #workers,
        clanBreakdown = clans,
        recruitmentCost = self.RECRUITMENT_COST
    }
end

return RecruitSystem 
