--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Button)
local Menu = require(script.Parent.Menu)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

export type Props = {
	layoutOrder: number,
	icon: string,
	menuId: string,
	notify: Vide.Source<boolean> | nil,
	onNotifyClick: (() -> ())?,
	notificationStyle: "badge" | "dot"?,
	visible: (() -> boolean | boolean)?,
}

local customRotations = {
	["shop"] = -14.7,
	["index"] = -14.34,
}

local show = Vide.show
local e = Vide.create

local function glowingDot()
	local pulse = Vide.source(0)
	local connection = RunService.RenderStepped:Connect(function()
		pulse((math.sin(os.clock() * 6) + 1) / 2)
	end)
	Vide.cleanup(connection)

	return e("Frame", {
		Size = usePx.offset(48, 48),
		Position = usePx.udim2(0, 99, 0, 14),
		BackgroundColor3 = Color3.fromRGB(255, 45, 45),
		BackgroundTransparency = function()
			return 0.82 - pulse() * 0.48
		end,
		ZIndex = 2,

		e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),

		e("UIStroke", {
			Color = Color3.fromRGB(255, 105, 105),
			Thickness = function()
				return usePx(4 + pulse() * 4)()
			end,
			Transparency = function()
				return 0.82 - pulse() * 0.5
			end,
		}),

		e("Frame", {
			Size = usePx.offset(26, 26),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),
			ZIndex = 3,

			e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),

			e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = usePx(3),
			}),
		}),
	})
end

return function(props: Props)
	return Button({
		Size = usePx.offset(145, 145),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,

		OnClick = function()
			if props.onNotifyClick then
				props.onNotifyClick()
			end
			Menu.setOpenedMenu(props.menuId)
		end,

		e("ImageLabel")({
			Size = usePx.offset(128, 128),
			Image = props.icon,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = customRotations[props.menuId] or 0,
			BackgroundTransparency = 1,
		}),

		show(function()
			return props.notify ~= nil and props.notify()
		end, function()
			if props.notificationStyle == "dot" then
				return glowingDot()
			end

			return e("Frame", {
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
			})
		end),

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
