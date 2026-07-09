local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local e = Vide.create

export type Props = {
	layoutOrder: number,
	icon: string,
	menuId: string,
	notify: Vide.Source<boolean> | nil,
}

local customRotations = {
	["shop"] = -14.7,
	["index"] = -14.34,
}

return function(props: Props)
	return e("TextButton")({
		Size = usePx.offset(145, 145),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		LayoutOrder = props.layoutOrder,

		e("ImageLabel")({
			Size = usePx.offset(128, 128),
			Image = props.icon,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = customRotations[props.menuId] or 0,
			BackgroundTransparency = 1,
		}),

		-- If the atom returns true it will create exclamination mark
		props.notify and props.notify() and e("Frame", {
			Size = usePx.offset(36, 36),
			Position = usePx.udim2(0, 105, 0, 20),
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),

			e("UICorner", {
				CornerRadius = usePx.udim(0, 6),
			}),

			e("UIStroke", {
				Thickness = usePx(4.5),
			}),

			e("TextLabel", {
				Text = "!",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),

				e("UIStroke", {
					Thickness = usePx(4.5),
				}),
			}),
		}),

		e("TextLabel", {
			Name = "ButtonText",
			Size = usePx.offset(145, 43),
			Position = usePx.udim2(0, 0, 0, 115),
			Text = string.upper(props.menuId),
			TextScaled = true,
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),

			e("UIStroke", {
				Thickness = usePx(4.8),
			}),
		}),
	})
end
