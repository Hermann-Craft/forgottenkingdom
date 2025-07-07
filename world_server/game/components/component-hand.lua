local HandComponent = require(_G.libDir .. "middleclass")("Hand")

HandComponent.static.name = "Hand"
HandComponent.static.client = true

function HandComponent:initialize(hand)
    self.hand = hand or nil
end

return HandComponent