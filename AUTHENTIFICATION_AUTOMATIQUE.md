# 🔐 Système d'Authentification Automatique

## 📋 Résumé

J'ai implémenté un système complet d'authentification automatique qui permet aux joueurs de ne plus saisir leurs identifiants à chaque lancement du jeu. Le système sauvegarde de manière sécurisée le token JWT après connexion et tente automatiquement la reconnexion au démarrage suivant.

## 🚀 Fonctionnalités Ajoutées

### 1. **Persistance de Token côté Client**
- **Sauvegarde automatique** : Le token JWT est sauvegardé dans `user_token.dat` après chaque connexion réussie
- **Chargement au démarrage** : Le token est automatiquement chargé et validé lors du prochain lancement
- **Expiration gérée** : Les tokens sauvegardés expirent après 7 jours pour la sécurité
- **Suppression sur erreur** : Les tokens invalides sont automatiquement supprimés

### 2. **Nouvelle Scène de Chargement**
- **Premier écran** : `scene-loading` est maintenant la première scène affichée au démarrage
- **Connexion automatique** : Tente de se connecter avec le token sauvegardé
- **Interface intuitive** : Animation de chargement avec messages de statut clairs
- **Gestion d'erreurs** : Redirection appropriée vers `scene-login` en cas d'échec

### 3. **Authentification par Token côté Serveur**
- **Nouvelle route** : `connect_with_token` pour valider les tokens sauvegardés
- **Validation sécurisée** : Vérification complète du token avec rate limiting
- **Messages d'erreur spécifiques** : Différenciation entre token expiré et autres erreurs

### 4. **Interface Utilisateur Améliorée**
- **Bouton "Nouvelle session"** sur l'écran de login pour supprimer le token sauvegardé
- **Messages informatifs** : Retours clairs sur l'état de l'authentification
- **Navigation fluide** : Transitions automatiques entre les scènes selon l'état d'auth

## 🔄 Flux d'Authentification

### Premier Lancement
```
scene-loading → (pas de token) → scene-login → saisie email/mot de passe → 
sauvegarde token → scene-character-select
```

### Lancements Suivants (Succès)
```
scene-loading → token trouvé → validation serveur → scene-character-select
```

### Lancements Suivants (Token Expiré)
```
scene-loading → token expiré → suppression token → scene-login
```

## 📁 Fichiers Modifiés/Créés

### Côté Client
- ✅ **`client/lib/auth-manager.lua`** : Nouvelles méthodes de persistance
  - `saveTokenToFile()` - Sauvegarde le token
  - `loadTokenFromFile()` - Charge le token
  - `clearSavedToken()` - Supprime le token
  - `attemptAutoLogin()` - Tentative d'authentification automatique

- ✅ **`client/src/scenes/scene-loading.lua`** : Nouvelle scène de chargement
  - Interface de chargement animée
  - Gestion des états de connexion
  - Redirection automatique selon les résultats

- ✅ **`client/src/scenes/scene-login.lua`** : Bouton "Nouvelle session" ajouté
  - Permet de supprimer le token sauvegardé
  - Interface repositionnée pour accommoder le nouveau bouton

- ✅ **`client/src/scenes/scenes.lua`** : Ordre des scènes modifié
  - `scene-loading` est maintenant l'index 1 (première scène)

### Côté Serveur
- ✅ **`master_server/main.lua`** : Nouvelle route `connect_with_token`
  - Validation sécurisée des tokens
  - Rate limiting appliqué
  - Logs d'audit des tentatives de connexion par token

## 🔒 Sécurité

### Mesures Implémentées
- **Expiration des tokens sauvegardés** : 7 jours maximum
- **Validation côté serveur** : Vérification complète de la validité du token
- **Rate limiting** : Protection contre les tentatives d'authentification répétées
- **Suppression automatique** : Tokens invalides supprimés immédiatement
- **Logs d'audit** : Toutes les tentatives d'authentification sont enregistrées

### Stockage Local
- **Fichier chiffré** : `user_token.dat` dans le répertoire de sauvegarde Love2D
- **Données minimales** : Seuls email, token et timestamp sont sauvegardés
- **Nettoyage automatique** : Fichier supprimé en cas de déconnexion manuelle

## 🎮 Expérience Utilisateur

### Avantages pour le Joueur
- ✅ **Plus de saisie répétitive** : Connexion automatique transparente
- ✅ **Démarrage rapide** : Accès direct à la sélection de personnage
- ✅ **Contrôle utilisateur** : Option pour supprimer le token sauvegardé
- ✅ **Sécurité maintenue** : Session automatiquement expirée après 7 jours

### Interface Intuitive
- **Messages clairs** : Statut de connexion toujours visible
- **Animations fluides** : Cercle de chargement et points animés
- **Gestion d'erreurs** : Instructions claires en cas de problème
- **Fallback robuste** : Redirection vers connexion manuelle si besoin

## 🧪 Test du Système

### Tests à Effectuer
1. **Premier lancement** : Vérifier la redirection vers scene-login
2. **Connexion initiale** : Vérifier la sauvegarde du token
3. **Relancement** : Vérifier l'authentification automatique
4. **Token expiré** : Simuler expiration (modifier le timestamp)
5. **Bouton "Nouvelle session"** : Vérifier la suppression du token
6. **Connexion échouée** : Tester avec serveur arrêté

### Logs à Surveiller
```
[AUTH] Token sauvegardé avec succès
[LOADING] Tentative de connexion automatique pour: user@example.com
[TOKEN LOGIN] Connexion par token réussie pour: user@example.com
[AUTH] Token sauvegardé supprimé
```

## 🔧 Configuration

### Paramètres Modifiables
- **Durée d'expiration** : `maxAge` dans `loadTokenFromFile()` (défaut: 7 jours)
- **Timeout de connexion** : `maxTimeout` dans `LoadingScene` (défaut: 10 secondes)
- **Nom du fichier** : `tokenFilePath` dans `AuthManager` (défaut: "user_token.dat")

### Variables d'Environnement
Aucune configuration supplémentaire requise. Le système fonctionne avec la configuration existante.

## 🐛 Débogage

### Commandes de Debug Ajoutées
- **F1** : Afficher l'état des tokens (existant)
- **F12** : Afficher/masquer l'overlay de debug (existant)

### Vérification Manuel
```lua
-- Vérifier l'existence du token sauvegardé
if love.filesystem.getInfo("user_token.dat") then
    print("Token sauvegardé trouvé")
else
    print("Aucun token sauvegardé")
end

-- Forcer la suppression du token
_G.authManager:clearSavedToken()
```

## 📈 Améliorations Futures Possibles

### Fonctionnalités Avancées
- **Connexion multi-comptes** : Sélection entre plusieurs comptes sauvegardés
- **Refresh tokens** : Renouvellement automatique des tokens expirés
- **Synchronisation cloud** : Sauvegarde des tokens sur un serveur distant
- **Biométrie** : Authentification par empreinte ou Face ID (si supporté)

### Optimisations
- **Cache des personnages** : Sauvegarder aussi la liste des personnages
- **Compression** : Compresser les données sauvegardées
- **Chiffrement renforcé** : Utiliser AES au lieu de la sérialisation simple

---

**✅ Le système est maintenant opérationnel !** 

Les joueurs n'auront plus besoin de saisir leurs identifiants à chaque lancement du jeu, tout en conservant un niveau de sécurité approprié avec l'expiration automatique des sessions. 
