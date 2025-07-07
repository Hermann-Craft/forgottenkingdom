return {
    Character = {
        "Position", -- { x, y }
        "Orientation", -- { orientation }
        "Dimension", -- { width, height }
        "Hand", -- { hand = Item = { onActivate } }
        "Eye", -- { viewDistance }
        "Intelligence", -- { intelligence }
        "Force", -- { force }
        "Speed", -- { speed, maxSpeed }
        "Agility", -- { agility }
        "Energy", -- { energy }
        "Life", -- { life }
        "Fame", -- { fame }
        "Wallet", -- { wallet = number }
        "Clan", -- { clan = string }
        "Quest", -- { quests = Quest }
        "Name", -- { name }
    },
    Projectile = {
        "Position",
        "Orientation",
        "Dimension",
        "Speed",
        "Force",
        "Distance",
        "Owner"
    },
    Player = {
        "Grade",
        "Position", -- { x, y }
        "Orientation", -- { orientation }
        "Dimension", -- { width, height }
        "Hand", -- { hand = Item = { onActivate } }
        "Eye", -- { viewDistance }
        "Intelligence", -- { intelligence }
        "Force", -- { force }
        "Speed", -- { speed, maxSpeed }
        "Agility", -- { agility }
        -- "Energy", -- { energy }
        "Life", -- { life }
        "Fame", -- { fame }
        "Shield", -- { activated }
        "Wallet", -- { wallet = number }
        "Clan", -- { clan = string }
        "Player", -- { composant joueur }
        "Quest", -- { quests = Quest }
        "Name", -- { name }
        "Texture" -- { name, index, size }
    },
    Mine = {
        "Position", -- { x, y }
        "Orientation", -- { orientation }
        "Dimension", -- { width, height }
        "Resources", -- { goldAmount, maxGold, state, respawnTimer }
        "Name", -- { name }
        "Texture" -- { name, index, size }
    }
}
