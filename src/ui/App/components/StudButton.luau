--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Button = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Button)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local RemoveKeys = require(ReplicatedStorage.Shared.Modules.Utils.RemoveKeys)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local derive = Vide.derive
local read = Vide.read

type Bindable<T> = T | () -> T

type StudButtonColors = {
	buttonStroke: Color3,
	outsideColor: ColorSequence,
	insideColor: ColorSequence,
	textStroke: Color3,
	buttonBase: Color3,
}

export type StudButton = Button.ButtonProps & {
	Colors: Bindable<StudButtonColors>,
	Text: string | () -> string,
	TextSize: (number | () -> number)?,
}

local CUSTOM_PROPS = {
	"Colors",
	"Text",
	"TextSize",
}

return function(props: StudButton)
	-- cached: reads props.Colors once per update, not once per consumer
	local colors = derive(function()
		return read(props.Colors)
	end)

	local safeProps = RemoveKeys(props, CUSTOM_PROPS) :: Button.ButtonProps
	safeProps.ImageTransparency = 1
	safeProps.BackgroundColor3 = function()
		return colors().buttonBase
	end
	safeProps.BackgroundTransparency = 0

	local buttonStroke = Vide.create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = function()
			return colors().buttonStroke
		end,
		LineJoinMode = Enum.LineJoinMode.Round,
		Thickness = usePx(3),
	})

	local title = TextLabel({
		Text = props.Text,
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.502, 0.467),
		Size = UDim2.fromScale(0.95, 0.718),
		TextScaled = if props.TextSize then false else true,
		TextSize = if props.TextSize then props.TextSize else 14,
		Stroke = {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = function()
				return colors().textStroke
			end,
			LineJoinMode = Enum.LineJoinMode.Bevel,
			Thickness = usePx(3),
		},
		ZIndex = 5,
	})

	local frameProps = {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.465),
		Size = UDim2.fromScale(1, 0.91),
		BackgroundTransparency = 0,
	} :: Frame.FrameProps

	local colorUIGradient = Vide.create("UIGradient", {
		Color = function()
			return colors().outsideColor
		end,
		Rotation = 90,
	})

	local studUIGradient = Vide.create("UIGradient", {
		Color = function()
			return colors().insideColor
		end,
		Rotation = 90,
	})

	local studImageLabelProps = {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.97, 0.885),
		Image = "rbxassetid://10509779001",
		ResampleMode = Enum.ResamplerMode.Default,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromScale(0.07, 0.325),
	} :: ImageLabel.ImageLabelProps

	table.insert(studImageLabelProps, studUIGradient)

	local studImage = ImageLabel(studImageLabelProps)

	table.insert(frameProps, studImage :: Instance)
	table.insert(frameProps, colorUIGradient)

	local colorFrame = Frame(frameProps :: Frame.FrameProps)

	table.insert(safeProps, buttonStroke)
	table.insert(safeProps, title)
	table.insert(safeProps, colorFrame)

	return Button(safeProps)
end
