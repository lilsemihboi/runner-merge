--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)

local messages = Vide.source({})
local id = 0

type NotificationMessageProps = {
	i: number,
	props: () -> TextLabel.TextLabelProps,
}

local function removeMessage(index: number)
	local current = table.clone(messages())
	current[index] = nil
	messages(current)
end

local function NotificationMessage(props: NotificationMessageProps)
	local visible = Vide.source(false)

	-- React useSpring(frequency = 2.5, damping = 1)
	-- ~= Vide.spring(period = 0.4, damping_ratio = 1)
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

	local closeThread = task.delay(6, function()
		visible(false)

		task.delay(0.4, function()
			removeMessage(props.i)
		end)
	end)

	Vide.cleanup(openThread)
	Vide.cleanup(closeThread)

	local textProps = props.props()
	textProps.Size = textProps.Size or UDim2.fromScale(1, 1)

	return Frame({
		LayoutOrder = -props.i,
		Size = size,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.25,

		Vide.create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.33, 0.5),
				NumberSequenceKeypoint.new(0.66, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),

		TextLabel(textProps),
	})
end

local function Component()
	local children = Vide.indexes(messages, function(messageProps, index)
		return NotificationMessage({
			i = index,
			props = messageProps,
		})
	end)

	return Vide.show(function()
		return next(messages()) ~= nil
	end, function()
		return Frame({
			Size = UDim2.new(0.55, 0, 0, 42),
			Position = UDim2.fromScale(0.5, 0.25),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			ZIndex = 2147483647,

			children,

			Vide.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.1, 0),
			}),
		})
	end)
end

local function add(props: TextLabel.TextLabelProps)
	id += 1

	local current = table.clone(messages())
	current[id] = props
	messages(current)
end

return {
	Component = Component,
	add = add,
}
