--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local RobuxButton = require(ReplicatedStorage.Shared.UI.App.Components.RobuxButton)
local ShopContentFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopContentFrame)
local ShopFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopFrame)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function otherCashProducts()
	local cash = getVideDataSource("cash")

	return Frame({
		BackgroundTransparency = 1,
		Size = usePx.offset(1008, 250),

		Vide.create("UIListLayout", {
			Padding = usePx.udim(0, 20),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		ShopFrame.Green({
			Size = usePx.offset(320, 250),
			LayoutOrder = 1,

			-- 20

			TextLabel({
				Text = function()
					return `+${Abbreviate(cash() * 0.2)}`
				end,
				Gradient = {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(98, 255, 12)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(153, 255, 81)),
					}),
				},
				Stroke = {
					Color = Color3.fromRGB(16, 83, 2),
					Thickness = usePx(5),
				},
				TextScaled = true,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Size = usePx.offset(688, 72),
				Position = UDim2.fromScale(0.4, 0.2),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}),

			ImageLabel({
				Image = "rbxassetid://117630190830410",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.2, 0.7),
				Size = usePx.offset(125, 125),
			}),

			RobuxButton({
				Colors = ButtonColors.Green,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = usePx.udim2(0.725, 0, 0.86, 0),
				product = Products.cashPack1,
				Size = usePx.offset(150, 52.5),
			}),
		}),

		ShopFrame.Green({
			Size = usePx.offset(320, 250),
			LayoutOrder = 2,
			--50

			TextLabel({
				Text = function()
					return `+${Abbreviate(cash() * 0.5)}`
				end,
				Gradient = {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(98, 255, 12)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(153, 255, 81)),
					}),
				},
				Stroke = {
					Color = Color3.fromRGB(16, 83, 2),
					Thickness = usePx(5),
				},
				TextScaled = true,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Size = usePx.offset(688, 72),
				Position = UDim2.fromScale(0.4, 0.2),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}),

			ImageLabel({
				Image = "rbxassetid://117630190830410",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.2, 0.7),
				Size = usePx.offset(125, 125),
			}),

			RobuxButton({
				Colors = ButtonColors.Green,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = usePx.udim2(0.725, 0, 0.86, 0),
				product = Products.cashPack2,
				Size = usePx.offset(150, 52.5),
			}),
		}),

		ShopFrame.Green({
			Size = usePx.offset(320, 250),
			LayoutOrder = 3,
			-- 125

			TextLabel({
				Text = function()
					return `+${Abbreviate(cash() * 1.25)}`
				end,
				Gradient = {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(98, 255, 12)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(153, 255, 81)),
					}),
				},
				Stroke = {
					Color = Color3.fromRGB(16, 83, 2),
					Thickness = usePx(5),
				},
				TextScaled = true,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				Size = usePx.offset(688, 72),
				Position = UDim2.fromScale(0.4, 0.2),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}),

			ImageLabel({
				Image = "rbxassetid://117630190830410",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.2, 0.7),
				Size = usePx.offset(125, 125),
			}),

			RobuxButton({
				Colors = ButtonColors.Green,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = usePx.udim2(0.725, 0, 0.86, 0),
				product = Products.cashPack3,
				Size = usePx.offset(150, 52.5),
			}),
		}),
	})
end

local function hugeCurrency()
	return ShopFrame.Green({
		Size = usePx.offset(1008, 225),
		LayoutOrder = 0,

		--Title
		TextLabel({
			Text = "Huge Cash Pack",
			Size = UDim2.fromScale(1, 0.2),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Position = usePx.udim2(0, 0, 0, 10),
			Stroke = { Thickness = 3, Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		ImageLabel({
			Image = "rbxassetid://117630190830410",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.1, 0.6),
			Size = usePx.offset(150, 150),
		}),

		TextLabel({
			Text = "+$1,000,000,000",
			Gradient = {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(98, 255, 12)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(153, 255, 81)),
				}),
			},
			Stroke = {
				Color = Color3.fromRGB(16, 83, 2),
				Thickness = usePx(5),
			},
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Size = usePx.offset(688, 72),
			Position = UDim2.fromScale(0.45, 0.6),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}),

		RobuxButton({
			Colors = ButtonColors.Green,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.87, 0, 0.78, 0),
			product = Products.cashPack4,
			Size = usePx.offset(200, 70),
		}),
	})
end

return function()
	return ShopContentFrame({
		Text = "~Currency~",
		LayoutOrder = 4,
		Padding = 5,

		hugeCurrency(),
		otherCashProducts(),
	})
end
