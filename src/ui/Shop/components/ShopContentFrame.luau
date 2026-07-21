local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local RemoveKeys = require(ReplicatedStorage.Shared.Modules.Utils.RemoveKeys)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

type ShopContentFrameProps = {
	Padding: number?,
	Text: string,
} & Frame.FrameProps

local CUSTOM_PROPS = {
	"Text",
	"Padding",
}

return function(props: ShopContentFrameProps)
	local safeProps = RemoveKeys(props, CUSTOM_PROPS)

	safeProps.Size = UDim2.fromScale(1, 0)
	safeProps.AutomaticSize = Enum.AutomaticSize.Y
	safeProps.BackgroundTransparency = 1

	local uiListLayout = Vide.create("UIListLayout", {
		Padding = usePx.udim(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Wraps = true,
	})

	local uiPadding = Vide.create("UIPadding", {
		PaddingTop = UDim.new(0, props.Padding or 0),
	})

	local title = TextLabel({
		Text = props.Text,
		Size = usePx.udim2(1, 0, 0, 60),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
		LayoutOrder = -2,
		Font = Enum.Font.BuilderSansExtraBold,
		TextScaled = true,
	})

	table.insert(safeProps, uiListLayout)
	table.insert(safeProps, uiPadding)
	table.insert(safeProps, title)

	return Frame(safeProps)
end
