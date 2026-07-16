--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function rebirthContainer()
	local cash = getVideDataSource("cash")

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
			Size = usePx.offset(880, 130),
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
		}),

		-- Cash required:

		TextLabel({
			Text = "Cash required:",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextScaled = true,
			Size = usePx.offset(400, 55),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 270),
			Stroke = {
				Thickness = usePx(4),
			},
		}),

		-- Requirement Bar

		Frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.5,
			Size = usePx.offset(700, 86),
			Position = usePx.udim2(0.5, 0, 0.65, 0),

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
				Size = usePx.offset(700, 86),
				Position = usePx.udim2(0.5, 0, 0.5, 0),

				TextLabel({
					Text = function()
						return `${Abbreviate(cash())} / $5K`
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
					BackgroundColor3 = Color3.fromRGB(77, 255, 0),
					BackgroundTransparency = 0,
					Size = Vide.derive(function()
						return UDim2.fromScale(cash() / 5000, 1)
					end),

					Vide.create("UIStroke", {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
						Color = Color3.fromRGB(171, 255, 102),
						LineJoinMode = Enum.LineJoinMode.Round,
						Thickness = usePx(3.5),
					}),
				}),
			}),
		}),

		-- Rebirth
		StudButton({
			Size = usePx.offset(372, 118),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.5, 0, 0.87, 0),
			Colors = ButtonColors.Red,
			Text = "Rebirth",
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
