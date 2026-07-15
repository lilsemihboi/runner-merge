--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local CoolTransistions = require(ReplicatedStorage.Shared.Modules.Ui.CoolTransistions)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local PlotServiceClient = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceClient)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

return function()
	local manager = CoolTransistions.TransitionManager.new(Players.LocalPlayer.PlayerGui)

	local isProcessing = Vide.source(false)

	local topbarPosition = Vide.spring(function()
		if Menu.openedMenu() == nil then
			-- Normal konum
			return usePx.udim2(0, 0, 0, 16)()
		else
			-- Yukarı kay
			return usePx.udim2(0, 0, 0, -120)()
		end
	end, 0.35, 0.8)

	return Frame({
		Size = usePx.udim2(1, 0, 0, 87),
		Position = topbarPosition,
		BackgroundTransparency = 1,
		Visible = true,

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
				if isProcessing() then
					return
				end

				isProcessing(true)
				manager:PlayInOut(1, function()
					PlotServiceClient:getPlot():teleportToBase()
					isProcessing(false)
				end, "Center", "Hexagon", 0.1)
			end,
			Active = function()
				return not isProcessing()
			end,
		} :: StudButton.StudButton),
	})
end
