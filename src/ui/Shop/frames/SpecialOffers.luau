--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local CarIds = require(ReplicatedStorage.Shared.Modules.Items.CarIds)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local RobuxButton = require(ReplicatedStorage.Shared.UI.App.Components.RobuxButton)
local RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)
local ShopContentFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopContentFrame)
local ShopFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopFrame)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function carBundle()
	return ShopFrame.Purple({
		Size = usePx.offset(1008, 250),
		LayoutOrder = 0,

		--Title
		TextLabel({
			Text = "Exclusive Car Bundle",
			Size = UDim2.fromScale(1, 0.2),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Position = usePx.udim2(0, 0, 0, 10),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		--Worths
		TextLabel({
			Text = "\u{E002}399",
			Size = usePx.offset(200, 45),
			Position = usePx.udim2(0, 780, 0, 100),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.BuilderSansExtraBold,
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,

			-- Red stick
			Frame({
				Size = UDim2.new(0.7, 0, 0, 5),
				Position = UDim2.fromScale(0.5, 0.45),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = -15,
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				BorderSizePixel = 0,
				BackgroundTransparency = 0,
			}),
		}),

		-- CONTENT
		Frame({
			Size = usePx.offset(700, 160),
			Position = usePx.udim2(0, 380, 0, 150),
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
					Text = `{CarIds[14].name}`,
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
					Image = CarIds[14].imageId,
					Size = UDim2.fromScale(1, 1),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.45, 0.45),
				}),

				TextLabel({
					Text = `Level 14`,
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
					Text = `{CarIds[15].name}`,
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
					Image = CarIds[15].imageId,
					Size = UDim2.fromScale(1, 1),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.45, 0.45),
				}),

				TextLabel({
					Text = `Level 15`,
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
					Text = `{CarIds[16].name}`,
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
					Image = CarIds[16].imageId,
					Size = UDim2.fromScale(1, 1),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.45, 0.45),
				}),

				TextLabel({
					Text = `Level 16`,
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

		TextLabel({
			Text = "Limited Time",
			TextScaled = true,
			Size = usePx.offset(200, 45),
			Position = usePx.udim2(0, 780, 0, 10),
			TextColor3 = Color3.fromRGB(255, 0, 0),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(87, 0, 0) },
			ZIndex = 3,
		}),

		RobuxButton({
			Colors = ButtonColors.Green,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.84, 0, 0.78, 0),
			product = Products.carBundle1,
			Size = usePx.offset(200, 70),
		}),
	})
end

local function starterPack()
	local owns = Vide.source(MonetizationServiceClient:ownsOneTimePurchase(Products.starterPack))

	if owns() then
		return nil
	end

	MonetizationServiceClient:getProductInfoChangedSignal(Products.starterPack):Connect(function()
		owns(MonetizationServiceClient:ownsOneTimePurchase(Products.starterPack))
	end)

	return ShopFrame.Blue({
		Size = usePx.offset(1008, 230),
		LayoutOrder = 0,
		Visible = function()
			return not owns()
		end,
		--Title
		TextLabel({
			Text = "Starter Pack",
			Size = UDim2.fromScale(1, 0.2),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Position = usePx.udim2(0, 0, 0, 10),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		--Worths
		TextLabel({
			Text = "\u{E002}149",
			Size = usePx.offset(200, 45),
			Position = usePx.udim2(0, 780, 0, 70),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.BuilderSansExtraBold,
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,

			-- Red stick
			Frame({
				Size = UDim2.new(0.7, 0, 0, 5),
				Position = UDim2.fromScale(0.5, 0.45),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = -15,
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				BorderSizePixel = 0,
				BackgroundTransparency = 0,
			}),
		}),

		-- Frame Content
		Frame({
			Size = usePx.offset(700, 160),
			Position = UDim2.fromScale(0.005, 0.98),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,

			Vide.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = usePx.udim(0, 20),
			}),

			-- Level 6 Car
			ShopFrame.Orange({
				Size = UDim2.fromScale(0.80, 0.80),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 1,

				TextLabel({
					Text = `{CarIds[6].name:upper()}`,
					Size = UDim2.fromScale(1.1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = usePx(20),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				-- Car Image
				ImageLabel({
					BackgroundTransparency = 1,
					Image = CarIds[6].imageId,
					Size = UDim2.fromScale(0.95, 0.95),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.46, 0.45),
				}),

				-- Car Bonus
				TextLabel({
					Text = `${Abbreviate(RunnerUtils.getRunnerIncomePerLap(6))}/lap`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Gradient = {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 255, 192)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 255, 0)),
						}),
						Rotation = 90,
					},
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

			ShopFrame.Green({
				Size = UDim2.fromScale(0.80, 0.80),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 3,

				TextLabel({
					Text = `MONEY`,
					Size = UDim2.fromScale(1.1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = usePx(20),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = "rbxassetid://117630190830410",
					Size = UDim2.fromScale(0.80, 0.80),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
				}),

				TextLabel({
					Text = `+$50k`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Gradient = {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 255, 192)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 255, 0)),
						}),
						Rotation = 90,
					},
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

			ShopFrame.Green({
				Size = UDim2.fromScale(0.80, 0.80),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 5,

				TextLabel({
					Text = `MONEY BONUS`,
					Size = UDim2.fromScale(1.1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = usePx(20),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					Image = "rbxassetid://121313278016619",
					Size = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.75, 0.33),
					BackgroundTransparency = 1,
					ZIndex = 2,
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = "rbxassetid://117630190830410",
					Size = UDim2.fromScale(0.80, 0.80),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
				}),

				TextLabel({
					Text = `+20%`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Gradient = {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 255, 192)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 255, 0)),
						}),
						Rotation = 90,
					},
				}),
			}),
		}),

		RobuxButton({
			Colors = ButtonColors.Green,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.87, 0, 0.78, 0),
			product = Products.starterPack,
			Size = usePx.offset(200, 70),
		}),
	})
end

return function()
	return ShopContentFrame({
		Text = "~Special Offer~",
		LayoutOrder = 0,
		Padding = 5,

		starterPack(),
		carBundle(),
	})
end
