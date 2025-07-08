local Worker = require(_G.libDir .. "middleclass")("Worker")

function Worker:initialize()
    -- Tag component - ajouté dès que le villageois rejoint un clan
end

Worker.static.client = true

return Worker 
