--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local PlotServiceClient = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceClient)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

return function()
	return Frame({
		Size = usePx.udim2(1, 0, 0, 87),
		Position = usePx.udim2(0, 0, 0, 16),
		BackgroundTransparency = 1,
		Visible = function()
			return Menu.openedMenu() == nil
		end,
		Vide.create("UIListLayout", {
			Padding = UDim.new(0.02, 0),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		StudButton({
			Size = usePx.offset(307, 87),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Colors = ButtonColors.Blue,
			Text = "Base",
			OnClick = function()
				PlotServiceClient:getPlot():teleportToBase()
			end,
		} :: StudButton.StudButton),
	})
end
