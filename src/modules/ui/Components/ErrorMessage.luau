--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local errors = Vide.source({})
local id = 0

type ErrorMessageProps = {
	i: number,
	message: () -> string,
}

local function removeError(index: number)
	local current = table.clone(errors())
	current[index] = nil
	errors(current)
end

local function ErrorMessage(props: ErrorMessageProps)
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

	-- Animate in on the next frame
	local openThread = task.defer(function()
		visible(true)
	end)

	-- Animate out after 3 seconds
	local closeThread = task.delay(3, function()
		visible(false)

		-- Wait roughly one spring period before removing
		task.delay(0.4, function()
			removeError(props.i)
		end)
	end)

	Vide.cleanup(openThread)
	Vide.cleanup(closeThread)

	return Frame({
		LayoutOrder = props.i,
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

		TextLabel({
			Size = UDim2.fromScale(1, 1),
			TextScaled = true,
			Text = props.message,
			TextColor3 = Color3.fromRGB(255, 0, 0),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			Stroke = {
				Color = Color3.fromRGB(87, 0, 0),
				Thickness = usePx(2.5),
			},
		}),
	})
end

local function Component()
	local children = Vide.indexes(errors, function(message, index)
		return ErrorMessage({
			i = index,
			message = message,
		})
	end)

	return Vide.show(function()
		return next(errors()) ~= nil
	end, function()
		return Frame({
			Size = UDim2.new(0.55, 0, 0, 30),
			Position = UDim2.fromScale(0.5, 0.9),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			ZIndex = 2147483647,

			children,

			Vide.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.1, 0),
			}),
		})
	end)
end

local function add(message: string)
	id += 1

	local current = table.clone(errors())
	current[id] = message
	errors(current)
end

return {
	Component = Component,
	add = add,
}
