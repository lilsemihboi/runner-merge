local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local MonetizationServiceUtils = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceUtils)
local Vide = require(ReplicatedStorage.Packages.Vide)

type Product = MonetizationServiceUtils.MonetizationProduct

return function(product: Product)
	local value = Vide.source(product)

	Vide.effect(function()
		local conn = MonetizationServiceClient:getProductInfoChangedSignal(product):Connect(function()
			value(table.clone(product))
		end)

		return function()
			conn:Disconnect()
		end
	end, { product })

	return value
end
