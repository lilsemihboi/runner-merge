--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

type SettingProps = {
	text: string,
	icon: string,
	path: string | { string },
	type: "slider",
} & Frame.FrameProps

local function settingsEntry(props: SettingProps) end

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
			Padding = usePx.udim(0, 10),
			Wraps = true,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			FillDirection = Enum.FillDirection.Horizontal,
		}),

		Vide.create("UIPadding", {
			PaddingTop = usePx.udim(0, 10),
			PaddingBottom = usePx.udim(0, 6),
			PaddingLeft = usePx.udim(0, 6),
			PaddingRight = usePx.udim(0, 6),
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
