-- Configuration des optimisations réseau pour réduire le lag
local NetworkConfig = {
    -- === PARAMÈTRES CLIENT ===
    CLIENT = {
        -- Throttling de l'orientation de la souris
        MOUSE_SEND_INTERVAL = 0.05,     -- Envoyer max 20 fois par seconde (au lieu de 60)
        MOUSE_MOVE_THRESHOLD = 5,       -- Seuil de mouvement minimal en pixels
        
        -- Throttling des mouvements
        MOVEMENT_SEND_INTERVAL = 0.016, -- Envoyer max 60 fois par seconde
        
        -- Autres optimisations
        SHOOT_BURST_LIMIT = 10,         -- Max 10 tirs par seconde
        ORIENTATION_CACHE_TIME = 0.033, -- Cache l'orientation pendant 33ms
    },
    
    -- === PARAMÈTRES SERVEUR ===
    SERVER = {
        -- Notifications de proximité
        MINE_NOTIFICATION_RADIUS = 300,     -- Rayon pour les notifications de mines
        VILLAGER_NOTIFICATION_RADIUS = 200, -- Rayon pour les notifications de villageois
        
        -- Fréquence des systèmes
        VILLAGER_AI_UPDATE_FREQ = 2.0,      -- IA villageois toutes les 2 secondes (au lieu de 0.5)
        COLLISION_UPDATE_FREQ = 0.033,      -- Collisions à 30 FPS (au lieu de 60)
        INTERACTION_UPDATE_FREQ = 0.1,      -- Interactions 10 fois par seconde
        
        -- Logs et debug
        REDUCE_LOGS = true,                 -- Réduire drastiquement les logs
        LOG_INTERVAL = 5.0,                 -- Logs détaillés toutes les 5 secondes max
        
        -- Cache et optimisations
        ENTITY_CACHE_SIZE = 1000,           -- Taille du cache d'entités
        CLEANUP_INTERVAL = 60.0,            -- Nettoyage toutes les minutes
    },
    
    -- === PARAMÈTRES DE BANDE PASSANTE ===
    BANDWIDTH = {
        -- Limites de données par seconde (en bytes)
        MAX_UDP_PER_CLIENT = 8192,          -- 8KB/s max par client UDP
        MAX_TCP_PER_CLIENT = 4096,          -- 4KB/s max par client TCP
        
        -- Compression et optimisation
        COMPRESS_LARGE_PACKETS = true,      -- Compresser les paquets > 1KB
        BATCH_SMALL_UPDATES = true,         -- Grouper les petites mises à jour
        
        -- Priorisation
        PRIORITY_MOVEMENT = 1,              -- Priorité haute pour mouvements
        PRIORITY_INTERACTION = 2,           -- Priorité moyenne pour interactions
        PRIORITY_COSMETIC = 3,              -- Priorité basse pour cosmétiques
    }
}

return NetworkConfig 
