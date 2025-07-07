# Textures - Forgotten Kingdom

## Structure des textures

Ce dossier contient toutes les textures utilisées dans le jeu côté client.

### 📁 Organisation

```
assets/textures/
├── entities/           # Textures des entités
│   ├── goldmine.png   # Texture de la mine d'or (48x48)
│   ├── player.png     # Texture du joueur
│   └── monsters/      # Textures des monstres
├── items/             # Textures des objets
│   ├── weapons/       # Armes
│   └── consumables/   # Objets consommables
├── ui/                # Textures d'interface
│   ├── buttons/       # Boutons
│   └── icons/         # Icônes
└── effects/           # Effets visuels
    ├── particles/     # Particules
    └── animations/    # Animations
```

### 🎨 Spécifications des textures

#### Mine d'or (`goldmine.png`)
- **Taille**: 48x48 pixels
- **Format**: PNG avec transparence
- **États**: 4 versions selon l'état de la mine
  - `goldmine_full.png` - Mine pleine (75-100% or)
  - `goldmine_partial.png` - Mine partiellement vidée (25-75% or)
  - `goldmine_low.png` - Mine presque vide (1-25% or)
  - `goldmine_empty.png` - Mine vide (0% or, en respawn)

#### Recommandations générales
- **Format**: PNG avec transparence alpha
- **Taille**: Multiples de 16 pixels (16x16, 32x32, 48x48, 64x64)
- **Qualité**: Pixel art style recommandé
- **Couleurs**: Palette limitée pour cohérence visuelle

### 🔧 Utilisation dans le code

Les textures sont référencées via le composant `Texture` :

```lua
-- Côté serveur (entity-goldmine.lua)
Components.Texture:new({
    name = "goldmine",    -- Nom du fichier sans extension
    index = 1,            -- Index pour les spritesheets
    size = 48             -- Taille en pixels
})
```

```lua
-- Côté client (world.lua - à implémenter)
local texture = love.graphics.newImage("assets/textures/entities/goldmine.png")
love.graphics.draw(texture, x, y)
```

### 📋 TODO pour la Phase 4

1. **Créer les textures de mine d'or** :
   - `goldmine_full.png` (48x48)
   - `goldmine_partial.png` (48x48)
   - `goldmine_low.png` (48x48)
   - `goldmine_empty.png` (48x48)

2. **Implémenter le système de rendu** :
   - Chargement des textures au démarrage
   - Rendu basé sur le composant Texture
   - Gestion des états de mine

3. **Optimisations** :
   - Cache des textures
   - Spritesheets pour les animations
   - Batching pour les performances 
