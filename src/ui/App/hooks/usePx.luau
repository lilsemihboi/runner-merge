local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local cleanup = Vide.cleanup
local derive = Vide.derive
local effect = Vide.effect
local source = Vide.source

local BASE_RESOLUTION = Vector2.new(1920, 1080)
local DOMINANT_AXIS = 0
local SCALE_POINTS = { 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 1, 1.25, 1.5, 2, 2.5, 3 }

local currentScale = source(1)

local function snap(scale: number): number
	local closest = SCALE_POINTS[1]
	local minDiff = math.huge

	for _, point in SCALE_POINTS do
		local diff = math.abs(scale - point)
		if diff < minDiff then
			minDiff = diff
			closest = point
		end
	end

	return closest
end

local function usePx()
	local viewportSize = source(Vector2.new(0, 0))

	local getConstrainedViewportSize = derive(function()
		local viewport = viewportSize()

		local aspect = viewport.X / viewport.Y
		local targetAspect = 16 / 9

		if aspect > targetAspect then
			return Vector2.new(viewport.Y * targetAspect, viewport.Y)
		else
			return viewport
		end
	end)

	effect(function()
		local viewport = getConstrainedViewportSize()

		local scaleX = math.log(viewport.X / BASE_RESOLUTION.X, 2)
		local scaleY = math.log(viewport.Y / BASE_RESOLUTION.Y, 2)

		local scale = 2 ^ math.lerp(scaleX, scaleY, DOMINANT_AXIS)

		currentScale(snap(scale))
	end)

	cleanup(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		viewportSize(workspace.CurrentCamera.ViewportSize)
	end))

	viewportSize(workspace.CurrentCamera.ViewportSize)
end

local function setScale(scale: number)
	currentScale(scale)
end

local function px(x: number): () -> number
	return function()
		return math.round(x * currentScale())
	end
end

local function raw(scaled: number): number
	return math.round(scaled / currentScale())
end

local function scale(x: number): () -> number
	return function()
		return x * currentScale()
	end
end

local function offset(x: number, y: number): () -> UDim2
	return function()
		return UDim2.fromOffset(px(x)(), px(y)())
	end
end

local function udim2(xScale: number, xOffset: number, yScale: number, yOffset: number): () -> UDim2
	return function()
		return UDim2.new(xScale, px(xOffset)(), yScale, px(yOffset)())
	end
end

local function udim(scalenumber: number, offsetnumber: number): () -> UDim
	return function()
		return UDim.new(scalenumber, px(offsetnumber)())
	end
end

return setmetatable({
	usePx = usePx,
	setScale = setScale,
	raw = raw,
	scale = scale,
	offset = offset,
	udim2 = udim2,
	udim = udim,
}, {
	__call = function(_, value: number): () -> number
		return px(value)
	end,
})
