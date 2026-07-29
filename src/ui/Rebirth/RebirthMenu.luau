--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local RebirthServiceClient = require(ReplicatedStorage.Shared.Services.RebirthService.RebirthServiceClient)
local RebirthServiceUtils = require(ReplicatedStorage.Shared.Services.RebirthService.RebirthServiceUtils)
local RobuxButton = require(ReplicatedStorage.Shared.UI.App.Components.RobuxButton)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

type RewardEntryProps = {
	Title: string,
	Value: string,
	Image: string,
	LayoutOrder: number,
}

local function rebirthRewardEntry(props: RewardEntryProps)
	return Frame({
		LayoutOrder = props.LayoutOrder,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		Size = usePx.offset(140, 140),

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

		ImageLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			Image = props.Image,
		}),

		TextLabel({
			Text = props.Title,
			Size = UDim2.fromScale(0.8, 0.5),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 5),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			ZIndex = 2,
			Stroke = { Thickness = usePx(4) },
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		}),

		TextLabel({
			Text = props.Value,
			Size = UDim2.fromScale(0.9, 0.25),
			Position = UDim2.fromScale(0.5, 0.95),
			AnchorPoint = Vector2.new(0.5, 1),
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Stroke = { Thickness = usePx(4) },
			TextColor3 = Color3.fromRGB(255, 255, 255),
			ZIndex = 2,
		}),
	})
end

local function rebirthContainer()
	local cash = getVideDataSource("cash")

	local rebirths = getVideDataSource("rebirths")

	local targetCash = Vide.derive(function()
		local cost = RebirthServiceUtils.calculateCashRequirement(rebirths() + 1)

		return cost
	end)

	local canAfford = Vide.derive(function()
		return cash() >= targetCash()
	end)

	local getsLevelReward = Vide.derive(function()
		local rebirth = rebirths() + 1
		return rebirth <= 80 and rebirth % 2 == 0
	end)

	return Frame({
		Size = usePx.offset(1008 * 0.9, 686 * 0.9),
		Position = usePx.udim2(0, 0, 0, 116 * 0.9),
		BackgroundTransparency = 1,

		-- YOU WILL LOSE YOUR CASH AND UPGRADES WHEN REBIRTH!

		TextLabel({
			Text = "[!] YOU WILL LOSE YOUR CASH AND UPGRADES WHEN YOU REBIRTH! [!]",
			Size = usePx.offset(880, 60),
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 27),
			TextColor3 = Color3.fromRGB(255, 255, 255),

			Vide.create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 81, 81)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 30, 30)),
				}),
			}),

			Stroke = {
				Thickness = usePx(3),
			},
		}),

		-- Rewards Container

		Frame({
			Size = usePx.offset(880, 170),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.5,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 130),
			Vide.create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.33, 0.5),
					NumberSequenceKeypoint.new(0.66, 0.5),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),

			Vide.create("UIListLayout", {
				Padding = usePx.udim(0, 30),
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			rebirthRewardEntry({
				Title = "Money Bonus",
				Value = "+5%",
				Image = "rbxassetid://117630190830410",
				LayoutOrder = 1,
			}),

			Vide.show(getsLevelReward, function()
				return rebirthRewardEntry({
					Title = "Car Spawn Level",
					Value = "+1",
					Image = "rbxassetid://83875092573507",
					LayoutOrder = 2,
				})
			end),
		}),

		-- Cash required:

		TextLabel({
			Text = "Cash required:",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextScaled = true,
			Size = usePx.offset(400, 55),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 310),
			Stroke = {
				Thickness = usePx(4),
			},
		}),

		-- Requirement Bar

		Frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.5,
			Size = usePx.offset(700, 66),
			Position = usePx.udim2(0.5, 0, 0.70, 0),

			Vide.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				BorderStrokePosition = Enum.BorderStrokePosition.Outer,
				Color = Color3.fromRGB(0, 0, 0),
				Transparency = 0.3,
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = usePx(4.5),
			}),

			-- Canvas Group
			Vide.create("CanvasGroup", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Size = usePx.offset(700, 66),
				Position = usePx.udim2(0.5, 0, 0.5, 0),

				TextLabel({
					Text = function()
						return `${Abbreviate(cash())} / ${Abbreviate(targetCash())}`
					end,
					Size = usePx.offset(368, 56),
					Stroke = {
						Thickness = usePx(4),
					},
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = usePx.udim2(0.5, 0, 0.5, 0),
					TextScaled = true,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					ZIndex = 20,
				}),

				-- Bar
				Frame({
					BackgroundColor3 = Vide.derive(function()
						return if canAfford() then Color3.fromRGB(77, 255, 0) else Color3.fromRGB(255, 42, 42)
					end),
					BackgroundTransparency = 0,
					Size = Vide.derive(function()
						return UDim2.fromScale(cash() / targetCash(), 1)
					end),

					Vide.create("UIStroke", {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
						Color = Vide.derive(function()
							return if canAfford() then Color3.fromRGB(171, 255, 102) else Color3.fromRGB(255, 140, 140)
						end),
						LineJoinMode = Enum.LineJoinMode.Round,
						Thickness = usePx(3.5),
					}),
				}),
			}),
		}),

		-- Rebirth
		StudButton({
			Size = usePx.offset(350, 100),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.3, 0, 0.89, 0),
			Colors = function()
				if canAfford() then
					return ButtonColors.Green
				end

				return ButtonColors.Red
			end,
			Text = "Rebirth",
			OnClick = function()
				RebirthServiceClient:rebirth()
			end,
		}),

		-- Skip Rebirth
		RobuxButton({
			Colors = ButtonColors.Blue,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.725, 0, 0.89, 0),
			product = Products.skipRebirth,
			Size = usePx.offset(350, 100),
			Text = "Skip",
		}),
	})
end

return {
	menuId = "Rebirth",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "Rebirth",
			Title = "Rebirth",
			Scale = 0.90,

			rebirthContainer(),
		})
	end,
}
