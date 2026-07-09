local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

return function()
	local cash = getVideDataSource("cash")

	return Frame({
		BackgroundTransparency = 1,
		Size = usePx.offset(333, 150),
		Position = usePx.udim2(0, 12, 0, 930),

		--Invite friend container
		Frame({
			BackgroundTransparency = 1,
			Size = usePx.offset(333, 45),

			-- Friend boost +0%
			TextLabel({
				Size = usePx.offset(260, 45),
				Position = usePx.udim2(0, 9, 0, 0),
				Text = "Friend boost +0%",
				TextScaled = true,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Stroke = {
					Thickness = usePx(3),
				},
				Font = Enum.Font.BuilderSansExtraBold,
			}),

			-- Plus Icon Invite Friend
			-- 269 + 24 padding that should give button size
			StudButton({
				Size = usePx.offset(40, 40),
				Colors = ButtonColors.Green,
				Position = usePx.udim2(0, 293, 0, 0),
				Text = "+",
				TextSize = usePx(60),
				OnClick = function()
					print("Invite friends prompt should open")
				end,
			} :: StudButton.StudButton),
		}),

		TextLabel({
			Position = usePx.udim2(0, 4, 0, 45),
			TextScaled = true,
			Size = usePx.offset(309, 90),
			Text = function()
				return `${Abbreviate(cash())}`
			end,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Stroke = {
				Thickness = usePx(5),
			},
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Gradient = {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 230, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 230, 0)),
				}),
				Rotation = 270,
				Enabled = true,
			},
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		}),
	})
end
