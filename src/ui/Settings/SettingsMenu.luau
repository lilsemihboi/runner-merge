--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
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
	type: "slider" | "toggle",
} & Frame.FrameProps

local activeSlider = Vide.source(nil)

local function isPointerInputType(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Touch
end

local function isPointerEndInputType(inputType: Enum.UserInputType): boolean
	return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

UserInputService.InputChanged:Connect(function(input)
	if not activeSlider() then
		return
	end

	if not isPointerInputType(input.UserInputType) then
		return
	end

	local position = input.Position

	local relative = math.clamp((position.X - activeSlider().slider.AbsolutePosition.X) / activeSlider().slider.AbsoluteSize.X, 0, 1)
	activeSlider().value(relative * 100)
end)

UserInputService.InputEnded:Connect(function(input)
	if not isPointerEndInputType(input.UserInputType) then
		return
	end

	local slider = activeSlider()
	if slider then
		slider.setValue(slider.value())
		slider.dragging(false)
		activeSlider(nil)
	end
end)

local function sliderControl(value, setValue)
	local clientValueSource = Vide.source(value())
	local dragging = Vide.source(false)

	local slider = nil

	Vide.effect(function()
		if not dragging() then
			clientValueSource(value())
		end
	end)

	return Frame({
		Vide.action(function(instance)
			slider = instance
		end),
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
			Colors = ButtonColors.Green,
			Text = Vide.derive(function()
				return tostring(math.floor(clientValueSource()))
			end),
			Size = usePx.offset(48, 48),
			Position = Vide.derive(function()
				return UDim2.fromScale(clientValueSource() / 100, 0.5)
			end),
			OnDown = function()
				dragging(true)

				activeSlider({
					slider = slider,
					value = clientValueSource,
					setValue = setValue,
					dragging = dragging,
				})
			end,
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
				Size = Vide.derive(function()
					return UDim2.fromScale(clientValueSource() / 100, 1)
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
	})
end

local function toggleControl(value, setValue)
	local isEnabled = Vide.derive(function()
		return value() ~= false
	end)

	return StudButton({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Colors = Vide.derive(function()
			return if isEnabled() then ButtonColors.Green else ButtonColors.Red
		end),
		Text = Vide.derive(function()
			return if isEnabled() then "ON" else "OFF"
		end),
		Size = usePx.offset(140, 64),
		Position = usePx.udim2(0.85, 0, 0.5, 0),
		OnClick = function()
			setValue(not isEnabled())
		end,
	} :: StudButton.StudButton)
end

local function settingsEntry(props: SettingProps)
	local value, setValue = useSetting(props.path)

	return Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		LayoutOrder = props.LayoutOrder,
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
			TextWrapped = false,
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

		-- Control
		if props.type == "toggle" then toggleControl(value, setValue) else sliderControl(value, setValue),
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

		settingsEntry({
			text = "Trails",
			icon = "rbxassetid://139759022914299",
			path = "trails",
			type = "toggle",
			LayoutOrder = 3,
		}),

		settingsEntry({
			text = "Indicators",
			icon = "rbxassetid://127468751750111",
			path = "moneyIndicator",
			type = "toggle",
			LayoutOrder = 4,
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
