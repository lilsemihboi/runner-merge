--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Menu = require(script.Parent.Menu)
local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local MonetizationServiceUtils = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceUtils)
local RemoveKeys = require(ReplicatedStorage.Shared.Modules.Utils.RemoveKeys)
local ShopSlice = require(ReplicatedStorage.Shared.UI.Shop.ShopSlice)
local StudButton = require(script.Parent.StudButton)
local Vide = require(ReplicatedStorage.Packages.Vide)
local useProduct = require(ReplicatedStorage.Shared.Services.MonetizationService.Hooks.useProduct)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local read = Vide.read
local derive = Vide.derive

type MonetizationProduct = MonetizationServiceUtils.MonetizationProduct

export type RobuxButtonProps = StudButton.StudButton & {
	product: MonetizationProduct,
	HideGift: (boolean | () -> boolean)?,
	OnPurchaseRequested: (() -> boolean?)?,
}

local CUSTOM_PROPS = {
	"product",
	"HideGift",
	"OnPurchaseRequested",
	"Position",
	"AnchorPoint",
	"ZIndex",
	"Text",
}

return function(props: RobuxButtonProps)
	local product = useProduct(props.product)

	local giftId = derive(function()
		local hideGifts = props.HideGift

		if typeof(hideGifts) == "function" then
			hideGifts = hideGifts()
		end

		if hideGifts ~= true then
			return product().giftId
		end

		return nil
	end)

	local cost = derive(function()
		return MonetizationServiceClient:getProductCostString(product())
	end)

	local buttonProps = RemoveKeys(props, CUSTOM_PROPS)
	buttonProps.LayoutOrder = 2
	buttonProps.TextWrapped = false

	buttonProps.Text = function()
		if props.Text then
			return `{props.Text} ({cost()})`
		end

		return cost()
	end

	buttonProps.OnClick = function()
		if props.OnPurchaseRequested and props.OnPurchaseRequested() == false then
			return
		end

		MonetizationServiceClient:promptProduct(props.product :: any)
	end

	local wrapperSize = derive(function()
		local size = read(props.Size)

		if giftId() == nil then
			return size
		end

		return UDim2.fromOffset(size.X.Offset + 60.5, size.Y.Offset)
	end)

	return Frame({
		ZIndex = props.ZIndex or 1,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		-- Forwarded so callers can order the wrapper inside a UIListLayout. The inner
		-- LayoutOrder below is fixed, because it only orders the gift button and the
		-- buy button relative to each other.
		LayoutOrder = props.LayoutOrder,
		Size = wrapperSize,
		BackgroundTransparency = 1,

		Vide.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = usePx.udim(0, 16),
		}),

		Vide.show(function()
			return giftId() ~= nil
		end, function()
			return StudButton({
				LayoutOrder = 1,
				AutoButtonColor = false,
				Colors = ButtonColors.Blue,
				Text = "",
				Size = usePx.offset(52.5, 52.5),

				OnClick = function()
					ShopSlice.state.giftingProduct(props.product)
					Menu.setOpenedMenu("GiftingMenu")
				end,

				ImageLabel({
					Size = UDim2.fromScale(0.725, 0.725),
					Image = "rbxassetid://103954741835714",
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					ZIndex = 5,
				}),
			})
		end),

		StudButton(buttonProps),
	})
end
