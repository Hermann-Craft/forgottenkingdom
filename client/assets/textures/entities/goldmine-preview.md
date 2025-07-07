# Prévisualisation de la texture goldmine

## 🎨 Rendu visuel implémenté

La texture `goldmine.png` (64x64) sera rendue avec les fonctionnalités suivantes :

### 🌈 Système de couleurs selon l'état

```lua
-- États des mines et couleurs associées
if eResources.state == "full" then
    colorR, colorG, colorB = 1, 0.84, 0      -- Doré pur
elseif eResources.state == "partial" then
    colorR, colorG, colorB = 1, 0.9, 0.3     -- Doré pâle
elseif eResources.state == "low" then
    colorR, colorG, colorB = 0.9, 0.8, 0.4   -- Jaunâtre
elseif eResources.state == "respawning" then
    colorR, colorG, colorB = 0.6, 0.6, 0.6   -- Gris
    colorA = 0.7                              -- Semi-transparent
end
```

### 📊 Infos visuelles au-dessus de la mine

- **⭐ Pleine** : Mine avec 75-100% d'or
- **◐ Partielle** : Mine avec 25-75% d'or  
- **◯ Faible** : Mine avec 1-25% d'or
- **⏳ XXs** : Mine vide en respawn (compte à rebours)

### 📊 Barre de progression d'or

```
[████████████████████████████████] 100%  ← Mine pleine
[██████████████████░░░░░░░░░░░░░░] 50%   ← Mine partielle
[██████░░░░░░░░░░░░░░░░░░░░░░░░░░] 20%   ← Mine faible
[░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0%    ← Mine vide
```

## 🔧 Intégration dans le rendu

### Avant (Phase 3)
```lua
-- Rectangle simple
love.graphics.rectangle("fill", x, y, width, height)
```

### Après (Phase 4)
```lua
-- Texture avec couleur d'état et infos
love.graphics.setColor(colorR, colorG, colorB, colorA)
love.graphics.draw(texture, x, y, rotation, scaleX, scaleY)
-- + barre de progression
-- + texte d'état
```

## 📱 Exemple de rendu en jeu

```
     ⭐ Pleine
   ┌─────────────┐
   │   TEXTURE   │  ← Texture goldmine.png colorée en doré
   │   GOLDMINE  │  
   │   64x64     │
   └─────────────┘
   [██████████████] 85%  ← Barre de progression dorée
```

## 🔄 Mise à jour en temps réel

Quand un joueur mine ou qu'une mine respawn :
1. Le serveur envoie `mine_state_update`
2. Le client met à jour `eResources.state` et `eResources.goldAmount`
3. Le rendu change automatiquement :
   - Nouvelle couleur
   - Nouveau texte d'état
   - Nouvelle barre de progression

## 🎯 Fallback

Si la texture `goldmine.png` n'est pas trouvée :
- Un rectangle gris avec bordure rouge est affiché
- Le système continue de fonctionner normalement
- Le message "[TEXTURE] Erreur chargement" apparaît dans les logs

## 📈 Performance

- **Cache de textures** : Chaque texture n'est chargée qu'une fois
- **Préchargement** : Les textures principales sont chargées au démarrage
- **Scaling automatique** : La texture s'adapte aux dimensions de l'entité
- **Batching** : Toutes les mines utilisent la même texture 
