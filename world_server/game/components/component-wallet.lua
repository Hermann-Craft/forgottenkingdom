local WalletComponent = require(_G.libDir .. "middleclass")("Wallet")

WalletComponent.static.name = "Wallet"
WalletComponent.static.client = true

function WalletComponent:initialize(wallet)
    self.wallet = wallet or 0
    self.maxWallet = 100
end

function WalletComponent:canAddGold(amount)
    return (self.wallet + amount) <= self.maxWallet
end

function WalletComponent:addGold(amount)
    local spaceAvailable = self.maxWallet - self.wallet
    local goldToAdd = math.min(amount, spaceAvailable)
    self.wallet = self.wallet + goldToAdd
    return goldToAdd, amount - goldToAdd -- retourne: or ajouté, or en excès
end

function WalletComponent:isFull()
    return self.wallet >= self.maxWallet
end

function WalletComponent:getGoldRatio()
    return self.wallet .. "/" .. self.maxWallet
end

return WalletComponent
