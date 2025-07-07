local EnergyComponent = require(_G.libDir .. "middleclass")("Energy")

EnergyComponent.static.name = "Energy"
EnergyComponent.static.client = false

function EnergyComponent:initialize(energy)
    self.energy = 0
    self.maxEnergy = energy or 0
end

return EnergyComponent