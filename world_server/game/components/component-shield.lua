local ArmorComponent = require(_G.libDir .. "middleclass")("Shield")

ArmorComponent.static.name = "Shield"
ArmorComponent.static.client = true

function ArmorComponent:initialize(armor)
    self.activated = false
    self.armor = armor or 100
    self.timerToGetArmor = 4;
end

function ArmorComponent:update(dt)
    if self.armor <= 0 then
        self.timerToGetArmor = self.timerToGetArmor - dt
    end

    if self.timerToGetArmor <= 0 then
        self.armor = 100
        self.timerToGetArmor = 1
    end

    if self.activated == false and self.armor < 100 then
        self.armor = self.armor + dt * 10
    end
end

function ArmorComponent:applyReducer(reducer)
    self.armor = self.armor - reducer
end

return ArmorComponent


-- Get the square points of the rectangle
