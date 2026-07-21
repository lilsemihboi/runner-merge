--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local RobuxButton = require(ReplicatedStorage.Shared.UI.App.Components.RobuxButton)
local ShopContentFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopContentFrame)
local ShopFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopFrame)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function otherGamepasses()
	return Frame({
		BackgroundTransparency = 1,
		Size = usePx.offset(1008, 250),

		Vide.create("UIListLayout", {
			Padding = usePx.udim(0, 41.5),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		ShopFrame.Red({
			Size = usePx.offset(476, 250),
			LayoutOrder = 1,

			TextLabel({
				Text = "Double Car Speed",
				Size = UDim2.fromScale(0.95, 0.3),
				TextScaled = true,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Position = usePx.udim2(0.5, 0, 0.15, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
				ZIndex = 3,
			}),

			ImageLabel({
				Image = "rbxassetid://133865466950767",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.15, 0.65),
				Size = usePx.offset(150, 150),
			}),

			TextLabel({
				Text = "Makes your cars 2x faster!",
				Size = UDim2.fromScale(0.65, 0.45),
				TextScaled = true,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Position = usePx.udim2(0.325, 0, 0.225, 0),
				Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
				ZIndex = 3,
				TextXAlignment = Enum.TextXAlignment.Right,
				BackgroundTransparency = 1,
			}),

			RobuxButton({
				Colors = ButtonColors.Green,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = usePx.udim2(0.76, 0, 0.825, 0),
				product = Products.x2Speed,
				Size = usePx.offset(200, 70),
			}),
		}),

		ShopFrame.Green({
			Size = usePx.offset(476, 250),
			LayoutOrder = 2,

			TextLabel({
				Text = "Double Cash",
				Size = UDim2.fromScale(0.95, 0.2),
				TextScaled = true,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Position = usePx.udim2(0.5, 0, 0.15, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
				ZIndex = 3,
			}),

			ImageLabel({
				Image = "rbxassetid://117630190830410",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.18, 0.65),
				Size = usePx.offset(150, 150),
			}),

			TextLabel({
				Text = "Gives you 2x cash!",
				Size = UDim2.fromScale(0.45, 0.45),
				TextScaled = true,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Position = usePx.udim2(0.525, 0, 0.225, 0),
				Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
				ZIndex = 3,
				TextXAlignment = Enum.TextXAlignment.Right,
				BackgroundTransparency = 1,
			}),

			RobuxButton({
				Colors = ButtonColors.Green,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = usePx.udim2(0.76, 0, 0.825, 0),
				product = Products.x2Cash,
				Size = usePx.offset(200, 70),
			}),
		}),
	})
end

local function vip()
	return ShopFrame.Gold({
		Size = usePx.offset(1008, 250),
		LayoutOrder = 0,

		TextLabel({
			Text = "VIP",
			Size = UDim2.fromScale(0.3, 0.3),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Position = usePx.udim2(0, 89, 0, 20),
			AnchorPoint = Vector2.new(0.5, 0),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		ImageLabel({
			Image = "rbxassetid://96059060916796",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.1, 0.7),
			Size = usePx.offset(150, 150),
		}),

		TextLabel({
			Text = "\n - Unlock all extra gates, \n - Earn +50% more cash, \n - Earn +50% offline cash, \n - VIP Chat title",
			Size = UDim2.fromScale(0.5, 1),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Position = usePx.udim2(0.45, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		RobuxButton({
			Colors = ButtonColors.Green,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.87, 0, 0.78, 0),
			product = Products.vip,
			Size = usePx.offset(200, 70),
		}),
	})
end

return function()
	return ShopContentFrame({
		Text = "~Passes~",
		LayoutOrder = 3,
		Padding = 5,

		vip(),
		otherGamepasses(),
	})
end
