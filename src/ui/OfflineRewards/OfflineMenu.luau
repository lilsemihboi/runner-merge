--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local RobuxButton = require(ReplicatedStorage.Shared.UI.App.Components.RobuxButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function offlineMenu()
	return Frame({
		Size = usePx.offset(1008 * 0.75, 686 * 0.75),
		Position = usePx.udim2(0, 0, 0, 116 * 0.75),
		BackgroundTransparency = 1,

		-- You have earned [1/4]:
		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 44),
			Text = "You have earned:",
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Size = usePx.offset(576, 57),
			Stroke = {
				Thickness = usePx(4),
				Color = Color3.fromRGB(0, 0, 0),
			},
			TextColor3 = Color3.fromRGB(255, 255, 255),
		}),

		-- $ Cash amount (using commas) [2/4]:
		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 130),
			Text = "$67,676,676",
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextScaled = true,
			Size = usePx.offset(658, 105),
			Stroke = {
				Thickness = usePx(5),
				Color = Color3.fromRGB(0, 0, 0),
			},
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Vide.create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(152, 221, 2)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(76, 237, 2)),
				}),
			}),
		}),

		-- Would you like to double it? [3/4]:
		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 275),
			Text = "Would you like to double it?",
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextScaled = true,
			Size = usePx.offset(673, 57),
			Stroke = {
				Thickness = usePx(5),
				Color = Color3.fromRGB(0, 0, 0),
			},
			TextColor3 = Color3.fromRGB(255, 255, 255),

			Vide.create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(2, 199, 237)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 160, 237)),
				}),
			}),
		}),

		-- Yes! (29RBXICON)

		RobuxButton({
			Colors = ButtonColors.Green,
			product = Products.doubleOfflineEarnings,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = usePx.offset(284, 93),
			Position = usePx.udim2(0.5, 0, 0, 425),
		} :: RobuxButton.RobuxButtonProps),
	})
end

return {
	menuId = "OfflineRewards",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "OfflineRewards",
			Title = "Welcome Back!",
			Scale = 0.75,

			offlineMenu(),
		})
	end,
}
