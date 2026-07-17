--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorTweaker = require(ReplicatedStorage.Shared.Modules.Platform.ColorTweaker)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Sift = require(ReplicatedStorage.Packages.Sift)
local Vide = require(ReplicatedStorage.Packages.Vide)

type StudFrameProps = Frame.FrameProps & {
	Gradient: ColorSequence,
	studColor: Color3?,
}

local function Background(props: ImageLabel.ImageLabelProps)
	local safeProps = Sift.Dictionary.copy(props)
	safeProps.Image = "rbxassetid://12055407192"
	safeProps.ScaleType = Enum.ScaleType.Tile
	safeProps.TileSize = UDim2.fromOffset(50, 50)
	safeProps.BorderSizePixel = 0
	return ImageLabel(safeProps)
end

return function(props: StudFrameProps)
	props.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local safeProps = Sift.Dictionary.removeKeys(props, "Gradient")

	local Stroke = Vide.create("UIStroke", {
		Color = Color3.fromRGB(0, 0, 0),
		Thickness = 4,
		LineJoinMode = Enum.LineJoinMode.Miter,
	})

	local InnerStroke = Vide.create("UIStroke", {
		Color = Color3.fromRGB(255, 255, 255),
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		Thickness = 4,
		LineJoinMode = Enum.LineJoinMode.Miter,

		Vide.create("UIGradient", {
			Color = ColorTweaker.tweakColorSequence(
				props.Gradient,
				{ saturationBoost = 0.66, valueBoost = 2, primaryColor = ColorTweaker.enums.primaryColors.master }
			),
			Rotation = 90,
		}),
	})

	local Gradient = Vide.create("UIGradient", {
		Color = props.Gradient,
		Rotation = 90,
	})

	local Studs = Background({
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = props.studColor or Color3.fromRGB(255, 255, 255),
		ZIndex = -1,
		ImageTransparency = 0.2,
	})

	table.insert(safeProps, Stroke)
	table.insert(safeProps, InnerStroke)
	table.insert(safeProps, Gradient)
	table.insert(safeProps, Studs)

	safeProps.BackgroundTransparency = 0

	return Frame(safeProps :: Frame.FrameProps)
end
