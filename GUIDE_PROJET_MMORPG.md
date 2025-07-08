# Guide du Projet MMORPG - Forgotten Kingdom

## Vue d'ensemble de l'architecture

Ce projet implémente un MMORPG utilisant une architecture client-serveur avec les composants suivants :

### Structure des dossiers
```
forgottenkingdom/
├── client/          # Client de jeu (LÖVE2D/Lua)
├── master_server/   # Serveur maître (authentification, comptes)
├── world_server/    # Serveur de monde (logique de jeu ECS)
└── docker-compose.yml
```

## Technologies utilisées

- **Langage** : Lua
- **Framework client** : LÖVE2D (Love2D)
- **Base de données** : Redis
- **Conteneurisation** : Docker
- **Communication réseau** : TCP (fiable) + UDP (temps réel)
- **Sérialisation** : Bitser + JSON
- **Architecture serveur** : ECS (Entity-Component-System)

## Architecture réseau

```
[Client LÖVE2D] 
     ↓ TCP (auth/chars)
[Master Server:8080] ←→ [Redis:6379]
     ↓ redirect
[World Server:8082] (TCP + UDP)
```

### Communication

1. **Client → Master Server** (TCP:8080)
   - Authentification utilisateur
   - Gestion des personnages
   - Sélection du monde

2. **Client → World Server** (TCP:8082 + UDP:8082)
   - TCP : Actions critiques (mining, interactions)
   - UDP : Mouvements, orientations (temps réel)

3. **Servers → Redis**
   - Persistance des comptes utilisateurs
   - Sauvegarde des personnages
   - Configuration des mondes

## Architecture ECS (World Server)

### Composants (`world_server/game/components/`)

Les composants stockent les données pures :

- **Position** : Coordonnées x,y
- **Orientation** : Direction du regard
- **Dimension** : Largeur/hauteur de l'entité
- **Force** : Puissance d'attaque
- **Intelligence** : Points d'intelligence
- **Speed** : Vitesse de déplacement
- **Life** : Points de vie
- **Shield** : Bouclier activable
- **Wallet** : Argent du joueur
- **Clan** : Appartenance à un clan
- **Player** : Marqueur entité joueur
- **Resources** : Pour les mines (or, état, respawn)

### Entités (`world_server/game/entities/`)

Les entités combinent des composants selon des compositions prédéfinies :

#### Composition Player
```lua
Player = {
    "Grade", "Position", "Orientation", "Dimension",
    "Hand", "Eye", "Intelligence", "Force", "Speed", 
    "Agility", "Life", "Fame", "Shield", "Wallet",
    "Clan", "Player", "Quest", "Name", "Texture"
}
```

#### Composition Projectile
```lua
Projectile = {
    "Position", "Orientation", "Dimension", 
    "Speed", "Force", "Distance", "Owner"
}
```

#### Composition Mine
```lua
Mine = {
    "Position", "Orientation", "Dimension",
    "Resources", "Name", "Texture"
}
```

### Systèmes (`world_server/game/systems/`)

Les systèmes contiennent la logique de jeu :

- **system-interaction** : Gestion proximité joueur-mine
- **system-projectile** : Déplacement et collisions des projectiles
- **system-connection-cleanup** : Nettoyage des connexions perdues
- **system-world_limit** : Limites du monde
- **system-entity_ai** : Intelligence artificielle
- **system-shield** : Gestion des boucliers
- **system-death** : Gestion de la mort des entités

### Moteur ECS (`world_server/lib/engine/`)

#### Entity.lua
```lua
Entity:initialize(id, components)
Entity:getComponent(name)
Entity:addComponent(component)
Entity:update(dt)
Entity:toNbt() -- Sérialisation pour réseau
```

#### World.lua
```lua
World:addEntity(entity)
World:getEntitiesWithComponent(name)
World:getEntitiesWithStrict(componentList)
World:getEntityById(id)
World:removeEntityById(id)
World:addSystem(system)
```

#### System.lua
```lua
System:initialize(world)
System:update(dt) -- À implémenter dans chaque système
```

## Client (LÖVE2D)

### Structure des scènes (`client/src/scenes/`)

Le client utilise un système de scènes :

- **scene-login** : Connexion utilisateur
- **scene-register** : Inscription
- **scene-character-select** : Sélection du personnage
- **scene-character-creation** : Création de personnage
- **scene-loading** : Chargement
- **scene-play** : Jeu principal
- **scene-world** : Sélection du monde

### Assets (`client/assets/`)
```
assets/
├── textures/
│   ├── entities/monsters/
│   ├── items/weapons/
│   ├── items/consumables/
│   └── ui/buttons/
└── [autres assets]
```

## Master Server

### Fonctionnalités principales

1. **Authentification sécurisée**
   - Hachage des mots de passe
   - Tokens JWT
   - Rate limiting
   - Protection contre les attaques

2. **Gestion des comptes**
   - Inscription/connexion
   - Validation des données
   - Historique de connexion

3. **Gestion des personnages**
   - Création avec validation
   - Liste des personnages
   - Sauvegarde en Redis

4. **Routage vers les mondes**
   - Plusieurs world servers possibles
   - Redirection selon la charge

### Sécurité implémentée

- **Rate limiting** par IP
- **Validation des entrées**
- **Hachage sécurisé** des mots de passe
- **Tokens d'authentification**
- **Logs de sécurité**

## World Server

### Boucle principale

```lua
function love.update(dt)
    -- Traitement des connexions TCP/UDP
    -- Mise à jour du monde ECS
    RealmWorld:update(dt)
    -- Envoi des mises à jour aux clients
end
```

### Gestion des connexions

```lua
Server.Clients = {
    [email] = {
        tcp = clientid_tcp,
        udp = clientid_udp,
        lastSeen = timestamp
    }
}
```

### Messages réseau

#### UDP (temps réel)
- `player_move` : Déplacement du joueur
- `player_orientation` : Orientation du regard
- `player_shoot` : Tir de projectile
- `player_shield` : Activation bouclier

#### TCP (fiable)
- `player_mine` : Demande de minage
- `mining_result` : Résultat du minage
- `entity_create` : Création d'entité
- `entity_remove` : Suppression d'entité

## Déploiement

### Docker Compose

```yaml
services:
  redis:
    image: redis:latest
    ports: ["6379:6379"]
    volumes: [redis_data:/data]
```

### Ports utilisés

- **8080** : Master Server (TCP)
- **8082** : World Server principal (TCP+UDP)
- **8083-8085** : Autres world servers
- **6379** : Redis

## Flux de connexion d'un joueur

1. **Authentification** : Client → Master Server
2. **Sélection personnage** : Client → Master Server
3. **Redirection monde** : Master Server → Client
4. **Connexion monde** : Client → World Server
5. **Synchronisation** : World Server → Client
6. **Jeu temps réel** : Client ↔ World Server (UDP/TCP)

## Exemple d'interaction : Minage

1. **Proximité** : `system-interaction` détecte joueur près mine
2. **Notification** : `mining_available` envoyé au client
3. **Action** : Joueur clique, `player_mine` envoyé
4. **Validation** : Serveur vérifie distance, état mine, espace inventaire
5. **Résultat** : `mining_result` renvoyé au client
6. **Mise à jour** : Portefeuille et mine mis à jour

## Ajout de nouvelles fonctionnalités

### Nouveau composant
1. Créer `component-nouveau.lua`
2. L'ajouter dans `components.lua`
3. L'inclure dans les compositions nécessaires
4. Mettre à jour les entités concernées

### Nouveau système
1. Créer `system-nouveau.lua` héritant de `System`
2. Implémenter `update(dt)`
3. L'ajouter au monde dans `main.lua`

### Nouvelle entité
1. Créer `entity-nouveau.lua`
2. Définir sa composition dans `compositions.lua`
3. Créer les méthodes spécifiques si nécessaire

## Debugging et logs

### Côté client
- Mode debug activable avec `_G.DEBUG_MODE`
- Overlay debug avec F12
- Logs dans `_G.DEBUG_LOGS`

### Côté serveur
- Logs dans `server.log` et `masterserver.log`
- Mode debug pour les systèmes ECS
- Tracking des connexions clients

## Bonnes pratiques

1. **Sécurité** : Toujours valider les données côté serveur
2. **Performance** : UDP pour fréquent, TCP pour critique
3. **ECS** : Composants = données, Systèmes = logique
4. **Réseau** : Minimiser les données envoyées
5. **Debugging** : Utiliser les logs et le mode debug

## Système de Villageois (En développement)

### État actuel : Phase 2 ✅ TERMINÉE

#### **Phase 1 ✅ Infrastructure ECS de base**
- Composants villageois (Villager, Hireable, Worker, Target)
- TaskEnum et extension composant Brain
- Entité Villager avec méthode recruit()
- Composition définie et tests validés

#### **Phase 2 ✅ Système de spawn et IA de base**

**Nouveaux systèmes créés :**

##### Système de spawn automatique
- `system-villager-spawn.lua` : Spawn automatique jusqu'à 4 villageois
- 4 zones de spawn prédéfinies avec position aléatoire
- Timer de 10s entre tentatives de spawn
- Génération automatique de noms et IDs uniques
- Méthode `forceSpawn()` pour tests

##### Système d'IA de base
- `system-villager-ai.lua` : IA avec mouvement aléatoire
- Tick rate de 0.5s (2 fois par seconde)
- Mouvement aléatoire pour tâche Idle (30% chance/tick)
- Pathfinding simple vers destinations
- Limites du monde respectées

##### Composant Target étendu
- Ajout propriétés `destination` et `isMoving`
- Support du mouvement continu
- Calcul de distance et arrivée à destination

##### Intégration RealmWorld
- Systèmes ajoutés au monde principal
- Debug activé par défaut pour Phase 2
- Méthodes utilitaires : `getVillagerStats()`, `forceSpawnVillager()`, `toggleVillagerDebug()`

**Tests automatisés :**
- `test_villager_phase2.lua` : Validation complète
- Tests systèmes, composants, intégration
- Mocks pour Love2D et world

#### **Phase 3 ✅ Détection de proximité et recrutement**

**Nouveaux systèmes créés :**

##### Extension système d'interaction
- **Extension `system-interaction.lua`** : Gestion des villageois en plus des mines
- Distance spécifique villageois : 80 pixels (vs 100 pour mines)
- Tracking proximité : `playersNearVillagers`
- Nouvelles méthodes : `checkProximityVillagers()`, `onPlayerNearVillager()`, `onPlayerLeftVillager()`
- Messages réseau : `villager_recruitment_available` et `villager_recruitment_unavailable`

##### Système de recrutement
- **Nouveau `system-recruit.lua`** : Gestion complète du recrutement
- Coût fixe : 25 or par villageois
- Validation : proximité, or suffisant, clan existant, villageois recrutables
- Méthode `handleRecruitmentRequest()` avec retour détaillé
- Gestion d'erreurs avec remboursement en cas d'échec
- Liaison avec système d'interaction pour vérification proximité

##### Messages réseau TCP
- **`player_recruit_villager`** : Demande de recrutement (playerId → villagerId)
- **`villager_recruitment_available`** : Notification possibilité recrutement
- **`villager_recruitment_unavailable`** : Fin de proximité
- **`recruitment_result`** : Résultat du recrutement (succès/échec + détails)

##### Intégration RealmWorld
- Système ajouté au monde principal avec debug villageois
- Nouvelles méthodes : `handleRecruitmentRequest()`, `getRecruitmentStats()`
- Debug synchronisé avec autres systèmes villageois

**Tests automatisés :**
- `test_villager_phase3.lua` : Validation complète
- Tests : proximité, recrutement valide, échecs (or, distance), intégration
- Tous tests passent ✅

**Correction bug :**
- **Bug Speed component** : Composant Speed mal initialisé avec table au lieu de nombre
- **Correction** : `entity-villager.lua` ligne 13 - passage d'un nombre au lieu d'une table
- **Validation** : Système IA fonctionne maintenant sans erreur arithmétique
- **Serveur** : Démarre correctement avec tous systèmes villageois actifs

#### **Phase 4 ✅ Menu contextuel et assignation de tâches**

**Nouveaux systèmes créés :**

##### Système de menu contextuel
- **Nouveau `system-context-menu.lua`** : Gestion complète des menus de villageois
- Validation : propriétaire (même clan), proximité, type Worker
- Méthodes : `handleMenuRequest()`, `handleTaskAssignment()`
- Construction dynamique du menu avec tâches disponibles/désactivées
- Phase 4 : Seules tâches Idle et Follow disponibles

##### Extension système d'IA 
- **Extension `system-villager-ai.lua`** : Implémentation tâche Follow
- Nouvelle méthode `findClanMaster()` : Trouve le joueur du même clan
- Comportement Follow intelligent : distance 60px (suivi) / 30px (arrêt)
- Mouvement vers position aléatoire près du maître
- Gestion absence de maître (immobilisation)

##### Extension système d'interaction
- **Extension `system-interaction.lua`** : Distinction Hireable vs Worker
- Double tracking : villageois recrutables et villageois workers
- Messages différenciés selon le type :
  - `villager_recruitment_available` pour Hireable
  - `villager_menu_available` pour Worker (propriétaire)
- Validation propriétaire dans messages Worker

##### Messages réseau TCP
- **`player_open_villager_menu`** : Demande d'ouverture menu (playerId → villagerId)
- **`villager_menu_data`** : Données du menu (tâches, stats, infos villageois)
- **`player_assign_task`** : Assignation tâche (playerId → villagerId → taskId)
- **`task_assignment_result`** : Résultat assignation (succès/échec + détails)
- **`villager_menu_available/unavailable`** : Notifications proximité Worker

##### Intégration RealmWorld
- Système ajouté au monde principal (Phase 2-4)
- Nouvelles méthodes : `handleMenuRequest()`, `handleTaskAssignment()`, `getMenuStats()`
- Debug synchronisé avec autres systèmes villageois

**Fonctionnalités Phase 4 :**

1. **Menu contextuel** : Joueur proche d'un Worker de son clan peut ouvrir menu
2. **Tâches disponibles** : Idle (Repos) et Follow (Suivre) opérationnelles
3. **Tâches futures** : ChopWood, MineGold, Defend (désactivées, Phases 5-7)
4. **Assignation robuste** : Validation propriétaire, proximité, tâche valide
5. **IA Follow intelligente** : Villageois suit son maître à distance optimale
6. **Interface unifiée** : Hireable → recrutement / Worker → menu contextuel

**Tests automatisés :**
- `test_villager_phase4.lua` : Validation complète
- Tests : menu valide, assignation, échecs propriétaire, IA Follow, intégration
- Tous tests passent ✅

#### **Phase 5 ✅ Ressources et récolte (ChopWood, MineGold)**

**Nouveaux composants créés :**

##### Composant Resource pour villageois
- **Nouveau `component-resource.lua`** : Système d'inventaire pour villageois
- Capacité de transport : 10 bois, 5 or maximum
- Méthodes : `addWood()`, `addGold()`, `canCarryWood()`, `canCarryGold()`, `clear()`
- État `isCarrying` et type de ressource ciblée `targetResource`
- Gestion intelligente des capacités avec retour d'overflow

##### Composant et entité TreeZone
- **Nouveau `component-tree-zone.lua`** : Zones de récolte de bois
- Système de récolte avec timer : 3 secondes par bois par défaut
- États : "available", "depleted", "respawning" 
- Gestion multi-villageois : tracking des récolteurs actifs
- Respawn automatique après épuisement (60s par défaut)
- **Nouvelle `entity-tree-zone.lua`** : Entité complète TreeZone
- Configurations variées : Forêt de Chênes, Bosquet de Pins, Sapinière
- Méthodes : `startHarvest()`, `completeHarvest()`, `canHarvest()`

##### Système de spawn TreeZones
- **Nouveau `system-tree-spawn.lua`** : Spawn automatique des zones d'arbres
- Maximum 6 zones d'arbres dans le monde
- 6 zones de spawn prédéfinies avec détection collision
- 3 configurations d'arbres avec ressources/temps variables
- Spawn intelligent évitant chevauchements
- Méthodes debug : `forceSpawnTreeZone()`, `getTreeStats()`

**Extension systèmes existants :**

##### Extension système d'IA (ChopWood et MineGold)
- **Extension `system-villager-ai.lua`** : Nouveaux comportements de récolte
- **Comportement ChopWood** :
  - Recherche automatique de TreeZone proche avec `findNearestTreeZone()`
  - Déplacement intelligent vers zone (distance 50px)
  - Gestion complète cycle récolte : start → progress → complete
  - Arrêt automatique si inventaire plein ou zone épuisée
- **Comportement MineGold** :
  - Recherche mines existantes avec `findNearestMine()`
  - Timer de minage simulé (2s par or)
  - Déplacement vers mine (distance 60px)
  - Épuisement mines et gestion états
- Réinitialisation complète lors changement tâche

##### Extension menu contextuel
- **Extension `system-context-menu.lua`** : Activation tâches Phase 5
- `isTaskAvailable()` étendue : ChopWood et MineGold maintenant disponibles
- Menu contextuel : 4 tâches actives (Idle, Follow, ChopWood, MineGold)
- Defend reste désactivée (Phase 7)
- Interface utilisateur prête pour ressources

**Intégration monde principal :**

##### Extension RealmWorld
- **Extension `world-realm.lua`** : Intégration TreeSpawnSystem
- Système ajouté aux systèmes actifs du monde
- Nouvelles méthodes : `forceSpawnTreeZone()`, `getTreeStats()`, `toggleTreeDebug()`
- Coexistence avec mines d'or existantes

##### Mise à jour entités villageois
- **Extension `entity-villager.lua`** : Composant Resource ajouté à la composition
- Tous villageois ont maintenant inventaire de ressources
- Persistence après recrutement
- **Extension `compositions.lua`** : Composition Villager et TreeZone définies

**Tests complets :**
- **Nouveau `test_villager_phase5.lua`** : Validation complète Phase 5
- Tests composants : Resource, TreeZone, entités
- Tests systèmes : TreeSpawn, IA étendue, menu contextuel
- Tests intégration : Workflow complet spawn → assign → récolte
- 48+ tests automatisés, tous passent ✅

### Prochaine phase : Phase 6 - Transport et stockage

## État final du développement villageois

- **Guide complet** créé et mis à jour avec tous les progrès
- **Phase 1, 2, 3, 4 et 5 terminées** avec succès et validation complète
- **Infrastructure ECS** villageois fonctionnelle et extensible
- **Spawn automatique** et **IA avancée** opérationnels
- **Système de recrutement** complet et fonctionnel
- **Menu contextuel et assignation** de tâches opérationnels
- **Tests automatisés** pour validation continue de tous les systèmes
- **Serveur stable** - tous bugs corrigés et validés
- **Architecture réseau** prête pour expansion Phase 5

**Fonctionnalités actives en production :**
1. **Spawn automatique** : 4 villageois + 6 zones d'arbres apparaissent automatiquement
2. **Mouvement autonome** : IA avec déplacement aléatoire intelligent  
3. **Détection proximité** : Joueur-villageois détectée à 80 pixels (différenciée Hireable/Worker)
4. **Recrutement complet** : Transaction 25 or avec validation robuste
5. **Transformation entité** : Hireable → Worker + assignation clan + inventaire ressources
6. **Menu contextuel** : Interface avec 4 tâches (Idle, Follow, ChopWood, MineGold)
7. **Assignation tâches** : Toutes les tâches de base opérationnelles
8. **IA Follow** : Villageois suit intelligemment son maître du clan
9. **IA ChopWood** : Récolte automatique de bois dans zones d'arbres (3s/bois)
10. **IA MineGold** : Minage automatique d'or dans mines existantes (2s/or)
11. **Système de ressources** : Inventaire villageois (10 bois, 5 or max)
12. **Zones d'arbres** : 6 zones avec respawn automatique après épuisement
13. **Messages réseau** : Notifications et interfaces temps réel au client
14. **Debug intégré** : Monitoring et logs pour tous systèmes villageois

**Prêt pour Phase 6** : Transport et stockage des ressources

---

*Ce guide est votre référence complète pour comprendre et développer le projet MMORPG Forgotten Kingdom. Consultez-le à chaque fois que vous avez besoin de vous remettre en contexte sur l'architecture du projet.* 
