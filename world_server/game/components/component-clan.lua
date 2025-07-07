local ClanComponent = require(_G.libDir .. "middleclass")("Clan")

ClanComponent.static.name = "Clan"
ClanComponent.static.client = true

function ClanComponent:initialize(name, fame)
    self.clanName = name
    self.clanFame = fame or 0
end

return ClanComponent