local Hireable = require(_G.libDir .. "middleclass")("Hireable")

function Hireable:initialize()
    -- Tag component - présent tant que le villageois n'est pas recruté
end

Hireable.static.client = true

return Hireable 
