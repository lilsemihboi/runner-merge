--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)
local useSetting = require(ReplicatedStorage.Shared.Services.SettingsService.Hooks.useSetting)

type SettingProps = {
	text: string,
	icon: string,
	path: string | { string },
	type: "slider",
} & Frame.FrameProps

local function settingsEntry(props: SettingProps)
	local value, setValue = useSetting(props.path)
	return Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		Size = usePx.offset((1008 * 0.8) - 48, 120),

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

		-- Icon

		ImageLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.icon,
			Size = usePx.offset(75, 75),
			Position = usePx.udim2(0.09, 0, 0.5, 0),
		}),

		-- Setting Text
		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = props.text,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Size = usePx.offset(250, 75),
			Position = usePx.udim2(0.325, 0, 0.5, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Stroke = {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				Color = Color3.fromRGB(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = usePx(6),
			},
		}),

		-- Bar
		props.type == "slider" and Frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.5,
			Size = usePx.offset(300, 24),
			Position = usePx.udim2(0.74, 0, 0.5, 0),

			Vide.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				BorderStrokePosition = Enum.BorderStrokePosition.Outer,
				Color = Color3.fromRGB(0, 0, 0),
				Transparency = 0.3,
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = usePx(4.5),
			}),

			StudButton({
				AnchorPoint = Vector2.new(0.5, 0.5),
				--AutoButtonColor = false
				Colors = ButtonColors.Green,
				Text = "100",
				Size = usePx.offset(48, 48),
				Position = usePx.udim2(1, 0, 0.5, 0),
				ZIndex = 2,
			} :: StudButton.StudButton),

			-- Canvas Group
			Vide.create("CanvasGroup", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Size = usePx.offset(300, 24),
				Position = usePx.udim2(0.5, 0, 0.5, 0),

				-- Bar
				Frame({
					BackgroundColor3 = Color3.fromRGB(77, 255, 0),
					BackgroundTransparency = 0,
					Size = usePx.offset(300, 24),

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
	})
end

local function settingsContainer()
	return Vide.create("ScrollingFrame", {
		Size = usePx.offset(1008 * 0.8, 686 * 0.8),
		Position = usePx.udim2(0, 0, 0, 116 * 0.8),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,

		Vide.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = usePx.udim(0, 20),
			Wraps = true,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			FillDirection = Enum.FillDirection.Horizontal,
		}),

		Vide.create("UIPadding", {
			PaddingTop = usePx.udim(0, 40),
			PaddingBottom = usePx.udim(0, 24),
			PaddingLeft = usePx.udim(0, 24),
			PaddingRight = usePx.udim(0, 24),
		}),

		settingsEntry({
			text = "Sounds",
			icon = "rbxassetid://105855463115764",
			path = "sounds",
			type = "slider",
			LayoutOrder = 1,
		}),

		settingsEntry({
			text = "Music",
			icon = "rbxassetid://113512493433629",
			path = "music",
			type = "slider",
			LayoutOrder = 2,
		}),
	})
end

return {
	menuId = "Settings",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "Settings",
			Title = "Settings",
			Scale = 0.8,

			settingsContainer(),
		})
	end,
}
