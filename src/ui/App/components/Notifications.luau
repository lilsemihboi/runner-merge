--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

type NotificationProps = {
	Image: string,
	Amount: number,
}

local notifications = Vide.source({})
local id = 0

local function removeNotification(index: number)
	local current = table.clone(notifications())
	current[index] = nil
	notifications(current)
end

local function Notification(props: {
	i: number,
	props: () -> NotificationProps,
})
	local visible = Vide.source(false)

	local size = select(
		1,
		Vide.spring(function()
			if visible() then
				return UDim2.fromScale(1, 1)
			end

			return UDim2.fromScale(0, 0)
		end, 0.4, 1)
	)

	local openThread = task.defer(function()
		visible(true)
	end)

	local closeThread = task.delay(5, function()
		visible(false)

		task.delay(0.4, function()
			removeNotification(props.i)
		end)
	end)

	Vide.cleanup(openThread)
	Vide.cleanup(closeThread)

	local data = props.props()

	return Frame({
		LayoutOrder = props.i,
		Size = size,
		BackgroundTransparency = 1,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,

		Vide.create("ImageLabel", {
			Image = data.Image,
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.5, 0.4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}),

		TextLabel({
			Text = "x" .. Abbreviate(data.Amount),
			Size = UDim2.fromScale(1, 0.3),
			Position = UDim2.fromScale(0.5, 0.85),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.BuilderSansExtraBold,
			Stroke = {
				Thickness = usePx(2),
			},
		}),
	})
end

local function Screen()
	local children = Vide.indexes(notifications, function(notificationProps, index)
		return Notification({
			i = index,
			props = notificationProps,
		})
	end)

	return Vide.show(function()
		return next(notifications()) ~= nil
	end, function()
		return Frame({
			Size = UDim2.new(1, 0, 0, 90),
			Position = UDim2.fromScale(0.5, 0.75),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 999999,

			children,

			Vide.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
		})
	end)
end

local function addNotification(props: NotificationProps)
	id += 1

	local current = table.clone(notifications())
	current[id] = props
	notifications(current)
end

return {
	Screen = Screen,
	addNotification = addNotification,
}
