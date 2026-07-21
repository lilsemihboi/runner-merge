local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

type PlayerPortraitProps = {
	userId: number?,
	Size: UDim2,
	Position: UDim2,
	StrokeColor: Color3?,
	SizeConstraint: Enum.SizeConstraint?,
	AnchorPoint: Vector2?,
} & Frame.FrameProps

return function(props: PlayerPortraitProps)
	local userId = props.userId
	local imageId = if userId then `https://www.roblox.com/headshot-thumbnail/image?userId={userId}&width=128&height=128&format=png` else ""

	return Frame({
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		SizeConstraint = props.SizeConstraint,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.8,

		ImageLabel({
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = imageId or "",
			ScaleType = Enum.ScaleType.Fit,

			Vide.create("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),

		Vide.create("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),

		Vide.create("UIStroke", {
			Color = props.StrokeColor or Color3.fromRGB(79, 79, 79),
			Thickness = usePx(2),
		}),
	})
end
