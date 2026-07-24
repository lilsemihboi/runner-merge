--!nonstrict
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local CarIds = require(ReplicatedStorage.Shared.Modules.Items.CarIds)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local PlotServiceClient = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceClient)
local ShopFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopFrame)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function container()
	return Frame({
		Size = usePx.offset(1008, 686),
		Position = usePx.udim2(0, 0, 0, 116),
		BackgroundTransparency = 1,

		-- LIMITED TIME! textlabel [1]

		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.045),
			Size = UDim2.fromScale(0.5, 0.045),
			Text = "LIMITED TIME!",
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 41, 41),
			Stroke = {
				Color = Color3.fromRGB(42, 5, 5),
				Thickness = usePx(3),
			},
			ZIndex = 2,
		}),

		-- <font color="rgb(0,255,0)">Like</font> and <font color="rgb(255,255,0)">Favorite</font> the game! [2]

		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.07),
			Position = UDim2.fromScale(0.5, 0.125),
			TextScaled = true,
			RichText = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = `1. <font color="rgb(0,255,0)">Like</font> and <font color="rgb(255,255,0)">Favorite</font> the game!`,
			Stroke = {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = usePx(3),
			},
			ZIndex = 2,
		}),

		-- ImageLabel for like and favorite

		ImageLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.521, 0.258),
			Image = "rbxassetid://132802642643340",
			Size = UDim2.fromScale(0.5, 0.28),
			Vide.create("UIAspectRatioConstraint", {
				AspectRatio = 2.022,
				AspectType = Enum.AspectType.FitWithinMaxSize,
				DominantAxis = Enum.DominantAxis.Width,
			}),
		}),

		-- Join our <font color="rgb(0,255,255)">Community</font>!

		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.075),
			Position = UDim2.fromScale(0.5, 0.385),
			TextScaled = true,
			RichText = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = `2. Join our <font color="rgb(0,255,255)">Community</font>!`,
			Stroke = {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = usePx(3),
			},
			ZIndex = 2,
		}),

		-- Stud button for join

		StudButton({
			Size = usePx.offset(320, 78),
			Position = usePx.udim2(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Colors = ButtonColors.Blue,
			Text = "Join",
			OnClick = function()
				GroupService:PromptJoinAsync(113923204)
			end,

			ImageLabel({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(1.005, 0.755),
				Rotation = -30,
				Size = UDim2.fromScale(0.374, 1.383),
				Image = "rbxassetid://81833703607942",
				ZIndex = 2,

				Vide.create("UIAspectRatioConstraint", {
					AspectRatio = 1,
					AspectType = Enum.AspectType.FitWithinMaxSize,
					DominantAxis = Enum.DominantAxis.Width,
				}),
			}),
		} :: StudButton.StudButton),

		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.4, 0.075),
			Position = UDim2.fromScale(0.5, 0.62),
			TextScaled = true,
			RichText = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = `3. Group <font color="rgb(255,0,150)">Rewards</font>:`,
			Stroke = {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = usePx(3),
			},
			ZIndex = 2,
		}),

		-- Frame Container For Rewards inside an ui list layout similar to exclusive car pack

		Frame({
			Size = UDim2.fromScale(1, 0.2),
			Position = UDim2.fromScale(0.5, 0.77),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,

			Vide.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = usePx.udim(0, 20),
			}),

			ShopFrame.Grey({
				Size = UDim2.fromScale(0.9, 0.9),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 1,

				TextLabel({
					Text = `{CarIds[4].name}`,
					Size = UDim2.fromScale(1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = CarIds[4].imageId,
					Size = UDim2.fromScale(1, 1),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.45, 0.45),
				}),

				TextLabel({
					Text = `Level 4`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
				}),
			}),

			TextLabel({
				Text = "+",
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				ZIndex = 99,
				LayoutOrder = 2,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Size = UDim2.fromScale(0.07, 0.9),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Stroke = {
					Thickness = usePx(4),
				},
			}),

			ShopFrame.Grey({
				Size = UDim2.fromScale(0.9, 0.9),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 3,

				TextLabel({
					Text = `MONEY BONUS`,
					Size = UDim2.fromScale(1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = "rbxassetid://117630190830410",
					Size = UDim2.fromScale(0.8, 0.8),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
				}),

				TextLabel({
					Text = `+5%`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
				}),
			}),

			TextLabel({
				Text = "+",
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				ZIndex = 99,
				LayoutOrder = 4,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Size = UDim2.fromScale(0.07, 0.9),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Stroke = {
					Thickness = usePx(4),
				},
			}),

			ShopFrame.Grey({
				Size = UDim2.fromScale(0.9, 0.9),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 5,

				TextLabel({
					Text = `MONEY`,
					Size = UDim2.fromScale(1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = "rbxassetid://117630190830410",
					Size = UDim2.fromScale(0.8, 0.8),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
				}),

				TextLabel({
					Text = `+$15K`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
				}),
			}),
		}),

		-- Claim Button Green [LAST] if success then setopenedmenu nil
		StudButton({
			Size = usePx.offset(350, 100),
			Position = usePx.udim2(0.5, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Colors = ButtonColors.Green,
			Text = "Claim",
			OnClick = function()
				local success = PlotServiceClient:getPlot():claimGroupRewards()
				if success then
					Menu.setOpenedMenu(nil)
				end
			end,
		}),
	})
end

return {
	menuId = "GroupRewards",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "GroupRewards",
			Title = "Group Rewards",
			Scale = 1,

			container(),
		})
	end,
}
