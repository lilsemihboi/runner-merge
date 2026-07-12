local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local MonetizationServiceUtils = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceUtils)
local RemoveKeys = require(ReplicatedStorage.Shared.Modules.Utils.RemoveKeys)
local StudButton = require(script.Parent.StudButton)
local Vide = require(ReplicatedStorage.Packages.Vide)
local useProduct = require(ReplicatedStorage.Shared.Services.MonetizationService.Hooks.useProduct)

type MonetizationProduct = MonetizationServiceUtils.MonetizationProduct
export type RobuxButtonProps = StudButton.StudButton & {
	product: MonetizationProduct,
	HideGift: boolean?,
	OnPurchaseRequested: (() -> boolean?)?,
}

local CUSTOM_PROPS = {
	"product",
	"HideGift",
	"OnPurchaseRequested",
}

return function(props: RobuxButtonProps)
	local product = useProduct(props.product)
	local _giftId = if props.HideGift then nil else product().giftId
	local cost = Vide.derive(function()
		return MonetizationServiceClient:getProductCostString(product())
	end)

	local buttonProps = RemoveKeys(props, CUSTOM_PROPS)

	buttonProps.OnClick = function()
		if props.OnPurchaseRequested and props.OnPurchaseRequested() == false then
			return
		end

		MonetizationServiceClient:promptProduct(props.product :: any)
	end
	buttonProps.Text = cost

	return StudButton(buttonProps)
end
