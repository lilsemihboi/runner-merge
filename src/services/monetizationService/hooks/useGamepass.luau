local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local MonetizationServiceUtils = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceUtils)
local Vide = require(ReplicatedStorage.Packages.Vide)

type Product = MonetizationServiceUtils.MonetizationProduct

return function(product: Product)
	local owns = Vide.source(MonetizationServiceClient:ownsGamepass(product :: any))

	Vide.effect(function()
		local conn = MonetizationServiceClient:getProductInfoChangedSignal(product):Connect(function()
			owns(MonetizationServiceClient:ownsGamepass(product :: any))
		end)

		return function()
			conn:Disconnect()
		end
	end, { product })

	return owns
end
