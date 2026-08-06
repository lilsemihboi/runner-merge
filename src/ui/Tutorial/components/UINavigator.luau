---------------------------------------------------------------------
------------          UI NAVIGATOR                   ----------------
------------        SESOCELL X KEBONDY               ----------------
---------------------------------------------------------------------

--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
const Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local useTargetRect = require(script.Parent.Parent.Hooks.useTargetRect)

local cleanup = Vide.cleanup
local derive = Vide.derive
local effect = Vide.effect
local source = Vide.source
local spring = Vide.spring

--[[
	Highlights a target by dimming everything around it.

	The dimming comes from a single `UIStroke` with an enormous thickness: the
	stroke paints outward from the (invisible) shadow frame, so the frame itself
	stays clear while the rest of the screen darkens. Moving and resizing that
	frame is what moves the spotlight.

	Targets can be a `GuiObject`, a `BasePart` or a `Model`; see `useTargetRect`
	for how each is resolved. Passing `nil` fades the highlight out.
]]

export type CursorSide = "left" | "right" | "top" | "bottom"

export type UINavigatorProps = {
	Target: () -> useTargetRect.Target?,
	Cursor: boolean?,
	CursorSide: (() -> CursorSide)?,
	DisplayOrder: number?,
}
-- The dimming is the outward half of this stroke, so it only covers the screen
-- while it reaches every corner. Because the shadow frame is rounded, the
-- stroke's outer contour is rounded by `CORNER_RADIUS + STROKE_THICKNESS`,
-- which means the thickness has to exceed the distance from the highlight to
-- the farthest corner of the viewport, not merely the viewport's size. At 1000
-- a highlight near one edge left the opposite edge and the corners undimmed.
local STROKE_THICKNESS = 10000
local STROKE_TRANSPARENCY = 0.25
local STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local CORNER_RADIUS = UDim.new(0, 10)
local PADDING = UDim.new(0, -10)

local CURSOR_IMAGE = "rbxassetid://130115090949871"
local CURSOR_SIZE = UDim2.fromOffset(100, 100)

local DEFAULT_DISPLAY_ORDER = 1_000_000

local HIDDEN_POSITION = UDim2.fromScale(-2.5, -2.5)
local HIDDEN_SIZE = UDim2.fromScale(5, 5)

local SPRING_PERIOD = 0.15
local SPRING_DAMPING = 1

local CURSOR_PLACEMENTS: { [CursorSide]: { rotation: number, position: UDim2 } } = {
	bottom = { rotation = 0, position = UDim2.fromScale(0.2, 0.8) },
	top = { rotation = 180, position = UDim2.fromScale(0.2, -1.25) },
	left = { rotation = 90, position = UDim2.fromScale(-0.5, -0.25) },
	right = { rotation = -90, position = UDim2.fromScale(1, -0.25) },
}

--- Returns `target` rewritten to the revolution nearest `current`.
--- Prevents a spring from unwinding the long way around, e.g. 350 -> 10
--- travelling 340 degrees instead of 20.
local function nearestEquivalentAngle(current: number, target: number): number
	local difference = (target - current) % 360

	if difference > 180 then
		difference -= 360
	end

	return current + difference
end

return function(props: UINavigatorProps)
	local rect = useTargetRect.useTargetRect(props.Target)
	local isVisible = derive(function()
		return rect() ~= nil
	end)

	-- The last known rect is retained while fading out, so the highlight
	-- shrinks away from where the target was rather than snapping to the
	-- screen corner.
	local lastRect = source(nil :: useTargetRect.Rect?)

	effect(function()
		local current = rect()

		if current ~= nil then
			lastRect(current)
		end
	end)

	-- Rotation accumulates rather than being read back from the instance:
	-- springs cannot sample their own output mid-flight without feeding back
	-- into themselves, so the unwrapped total is tracked separately.
	local unwrappedRotation = source(0)

	effect(function()
		local current = rect()

		if current == nil then
			return
		end

		unwrappedRotation(nearestEquivalentAngle(unwrappedRotation(), current.rotation))
	end)

	local targetPosition = derive(function()
		local current = lastRect()

		if current == nil or not isVisible() then
			return HIDDEN_POSITION
		end

		-- AbsolutePosition is inset-relative, but this ScreenGui ignores the
		-- inset, so the inset has to be added back for the two to line up.
		local inset = useTargetRect.getGuiInset()

		return UDim2.fromOffset(current.position.X + inset.X, current.position.Y + inset.Y)
	end)

	local targetSize = derive(function()
		local current = lastRect()

		if current == nil or not isVisible() then
			return HIDDEN_SIZE
		end

		return UDim2.fromOffset(current.size.X, current.size.Y)
	end)

	-- Three springs for the lifetime of the component, rather than three Tween
	-- objects per frame. The old implementation rebuilt a 1s tween every
	-- RenderStepped, which meant it restarted before it could ever finish and
	-- the highlight permanently trailed its target.
	local position = spring(targetPosition, SPRING_PERIOD, SPRING_DAMPING)
	local size = spring(targetSize, SPRING_PERIOD, SPRING_DAMPING)
	local rotation = spring(unwrappedRotation, SPRING_PERIOD, SPRING_DAMPING)

	local strokeTransparency = spring(function()
		return if isVisible() then STROKE_TRANSPARENCY else 1
	end, SPRING_PERIOD, SPRING_DAMPING)

	local cursorPlacement = derive(function()
		local side = if props.CursorSide then props.CursorSide() else "bottom"
		return CURSOR_PLACEMENTS[side] or CURSOR_PLACEMENTS.bottom
	end)

	local screenGui = Vide.create("ScreenGui", {
		Name = "TutorialNavigator",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ClipToDeviceSafeArea = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = props.DisplayOrder or DEFAULT_DISPLAY_ORDER,
		Enabled = isVisible,

		Frame({
			Name = "mainFrame",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 999999999,
			Position = position,
			Size = size,
			Rotation = rotation,

			Vide.create("UIPadding", {
				PaddingTop = PADDING,
				PaddingBottom = PADDING,
				PaddingLeft = PADDING,
				PaddingRight = PADDING,
			}),

			Vide.create("Frame", {
				Name = "shadow",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 999999999,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),

				Vide.create("UICorner", {
					CornerRadius = CORNER_RADIUS,
				}),

				Vide.create("UIStroke", {
					Color = STROKE_COLOR,
					Thickness = STROKE_THICKNESS,
					Transparency = strokeTransparency,
					LineJoinMode = Enum.LineJoinMode.Bevel,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				}),
			}),
			-- Parented to the highlight itself so the scale-based placements in
			-- CURSOR_PLACEMENTS resolve against the target rect. As a direct
			-- child of the ScreenGui they resolved against the whole viewport,
			-- which stranded the cursor away from whatever was highlighted.
			if props.Cursor
				then Vide.create("ImageLabel", {
					Name = "pointer",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 999999999,
					Image = CURSOR_IMAGE,
					Size = CURSOR_SIZE,
					Rotation = function()
						return cursorPlacement().rotation
					end,
					Position = function()
						return cursorPlacement().position
					end,
				})
				else nil,
		}),
	})

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	cleanup(function()
		screenGui:Destroy()
	end)

	return screenGui
end
