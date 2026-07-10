local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonetizationServiceUtils = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceUtils)

type MonetizationProduct = MonetizationServiceUtils.MonetizationProduct

local products = {
	doubleOfflineEarnings = {
		id = 3609107348,
	} :: MonetizationProduct,
}

return products :: { [keyof<typeof(products)>]: MonetizationProduct }
