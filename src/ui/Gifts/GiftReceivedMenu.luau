--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local FormatNameWithIcons = require(ReplicatedStorage.Shared.Modules.Ui.FormatNameWithIcons)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local ShopSlice = require(ReplicatedStorage.Shared.UI.Shop.ShopSlice)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function content()
	local receivedData = ShopSlice.state.giftReceivedData
	if not receivedData() then
		return nil
	end

	local playerName = "UNKNOWN"
	local sender = Players:GetPlayerByUserId(receivedData.giftData.fromUserId)
	if sender then
		playerName = FormatNameWithIcons(sender)
	end

	local product = receivedData.product
	local productInfo = MonetizationServiceClient:getProductInfo(product)

	return Frame({
		Size = usePx.offset(1008 * 0.85, 686 * 0.85),
		Position = usePx.udim2(0, 0, 0, 116 * 0.85),
		BackgroundTransparency = 1,

		TextLabel({
			Text = `{playerName} has gifted you:\n<font size="60">{productInfo.Name}</font>`,
			TextSize = 30,
			TextScaled = true,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.9, 0.5),
			Position = UDim2.fromScale(0.5, 0.125),
			AnchorPoint = Vector2.new(0.5, 0),
			RichText = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Stroke = { Thickness = usePx(3) },
		}),

		StudButton({
			Size = usePx.offset(407, 107),
			Position = usePx.udim2(0.5, 0, 0.825, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Colors = ButtonColors.Green,
			Text = "Claim",
			OnClick = function()
				Menu.setOpenedMenu(nil)
				ShopSlice.state.giftReceivedData(nil)
			end,
		} :: StudButton.StudButton),
	})
end

return {
	menuId = "GiftReceivedMenu",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "GiftReceivedMenu",
			Title = "Gift Received",
			Scale = 0.85,

			content(),
		})
	end,
}
