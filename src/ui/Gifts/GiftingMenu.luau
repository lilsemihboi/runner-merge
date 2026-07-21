--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local ErrorMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.ErrorMessage)
local FormatNameWithIcons = require(ReplicatedStorage.Shared.Modules.Ui.FormatNameWithIcons)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local PlayerPortrait = require(ReplicatedStorage.Shared.Modules.Ui.Components.PlayerPortrait)
local ShopSlice = require(ReplicatedStorage.Shared.UI.Shop.ShopSlice)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

type PlayerCardProps = {
	Player: Player,
	LayoutOrder: number,
}

local function PlayerCard(props: PlayerCardProps)
	local product = ShopSlice.state.giftingProduct
	return Frame({
		Size = usePx.udim2(1, 0, 0, 140),
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,

		-- Inner stroke
		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = Color3.fromRGB(255, 255, 255),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = usePx(6),
			Transparency = 0.5,
		}),

		-- Outer Stroke
		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			BorderStrokePosition = Enum.BorderStrokePosition.Outer,
			Color = Color3.fromRGB(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = usePx(6),
			Transparency = 0.5,
		}),

		PlayerPortrait({
			Size = UDim2.fromScale(0.6767, 0.6767),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Position = UDim2.fromScale(0.05, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			userId = props.Player.UserId,
		}),

		TextLabel({
			Text = FormatNameWithIcons(props.Player),
			Size = UDim2.fromScale(0.5, 0.5),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0.425, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Stroke = { Thickness = usePx(3) },
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextScaled = true,
		}),

		StudButton({
			Size = usePx.offset(215, 67),
			Position = usePx.udim2(0.85, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Colors = ButtonColors.Green,
			Text = "Gift",
			OnClick = function()
				if not product() then
					return
				end

				local success, err = MonetizationServiceClient:promptGift(props.Player.UserId, product)
				if not success then
					ErrorMessage.add(err or "Failed to send gift.")
				end
			end,
		} :: StudButton.StudButton),
	})
end

local function playersList()
	local players = Vide.source(Players:GetPlayers())

	Vide.effect(function()
		local function update()
			players(Players:GetPlayers())
		end

		local addedConn = Players.PlayerAdded:Connect(update)
		local removedConn = Players.PlayerRemoving:Connect(update)

		Vide.cleanup(function()
			addedConn:Disconnect()
			removedConn:Disconnect()
		end)
	end)

	return Vide.create("ScrollingFrame", {
		Size = usePx.offset(1008 * 0.9, 686 * 0.9),
		Position = usePx.udim2(0, 0, 0, 116 * 0.9),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,

		Vide.create("UIListLayout", {
			Padding = usePx.udim(0, 20),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),

		Vide.create("UIPadding", {
			PaddingTop = usePx.udim(0, 25),
			PaddingBottom = usePx.udim(0, 25),
			PaddingLeft = usePx.udim(0, 18),
			PaddingRight = usePx.udim(0, 18),
		}),

		Vide.indexes(players, function(player, index)
			if player == Players.LocalPlayer then
				return
			end

			return PlayerCard({
				Player = player(),
				LayoutOrder = index,
			})
		end),
	})
end

return {
	menuId = "GiftingMenu",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "GiftingMenu",
			Title = "Gift",
			Scale = 0.9,
			OnClose = function()
				Menu.setOpenedMenu("Shop")
			end,

			playersList(),
		})
	end,
}
