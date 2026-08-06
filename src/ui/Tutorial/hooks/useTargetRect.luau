const GuiService = game:GetService("GuiService")
const RunService = game:GetService("RunService")

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Vide = require(ReplicatedStorage.Packages.Vide)

const cleanup = Vide.cleanup
const effect = Vide.effect
const source = Vide.source

--[[
	Resolves a tracking target into a screen-space rectangle.

	Targets can be a `GuiObject`, a `BasePart` or a `Model`, and the returned
	source updates as the target (or, for world targets, the camera) moves.
	Returns `nil` whenever there is no target or the target is not visible.

	Coordinate space
	----------------
	All values are in `AbsolutePosition` space, which is what `GuiObject`
	reports and what `Camera:WorldToScreenPoint()` returns. Note this space is
	offset from the raw viewport by the GUI inset:

		WorldToViewportPoint == WorldToScreenPoint + GetGuiInset()

	`AbsolutePosition` stays inset-relative even on a `ScreenGui` with
	`IgnoreGuiInset = true` -- such a frame at `Position = 0,0` reports an
	`AbsolutePosition` of `(0, -36)`. Consumers rendering into an inset-ignoring
	`ScreenGui` must therefore add the inset back when assigning `Position`.
	`getGuiInset()` is exported for exactly that.
]]

export type Target = GuiObject | BasePart | Model

export type Rect = {
	position: Vector2,
	size: Vector2,
	rotation: number,
}

-- A corner must be at least this many studs in front of the camera to count.
-- Points at or behind the camera plane project to mirrored garbage, so they are
-- excluded from the bounds entirely rather than merely counted. Including them
-- inflates the rect without limit -- measured at 725px -> 3627px -> `inf` on a
-- 1183x635 viewport for a part straddling the camera, versus a stable 18px when
-- filtered.
const MIN_DEPTH = 0.5

const UNIT_CORNERS = {
	Vector3.new(-0.5, -0.5, -0.5),
	Vector3.new(-0.5, -0.5, 0.5),
	Vector3.new(-0.5, 0.5, -0.5),
	Vector3.new(-0.5, 0.5, 0.5),
	Vector3.new(0.5, -0.5, -0.5),
	Vector3.new(0.5, -0.5, 0.5),
	Vector3.new(0.5, 0.5, -0.5),
	Vector3.new(0.5, 0.5, 0.5),
}

const function isWorldTarget(target: Instance): boolean
	return target:IsA("BasePart") or target:IsA("Model")
end

--- Reads the world-space bounds of a part or model.
const function getWorldBounds(target: Instance): (CFrame?, Vector3?)
	if target:IsA("BasePart") then
		return target.CFrame, target.Size
	elseif target:IsA("Model") then
		return target:GetBoundingBox()
	end

	return nil, nil
end

--- Projects a world-space box onto the screen, returning its bounding rect.
--- Returns `nil` when no corner is in front of the camera.
const function projectBounds(camera: Camera, cframe: CFrame, size: Vector3): Rect?
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local visible = false

	for _, unit in UNIT_CORNERS do
		local corner = cframe:PointToWorldSpace(unit * size)
		local point = camera:WorldToScreenPoint(corner)

		if point.Z > MIN_DEPTH then
			visible = true

			minX = math.min(minX, point.X)
			minY = math.min(minY, point.Y)
			maxX = math.max(maxX, point.X)
			maxY = math.max(maxY, point.Y)
		end
	end

	if not visible then
		return nil
	end

	return {
		position = Vector2.new(minX, minY),
		size = Vector2.new(maxX - minX, maxY - minY),
		-- Screen-space AABBs are axis-aligned by construction, so a world
		-- target never contributes rotation.
		rotation = 0,
	}
end

--- Returns the current GUI inset, for converting into inset-ignoring GUIs.
const function getGuiInset(): Vector2
	local topLeft = GuiService:GetGuiInset()
	return topLeft
end

--[[
	Returns the `SurfaceGui` and adornee part a `guiObject` is drawn on, if any.

	`AbsolutePosition` and `AbsoluteSize` on a `SurfaceGui` descendant are
	measured in the surface's own canvas space, which has no relationship to the
	screen: the values do not change as the camera moves, and canvas pixels are
	typically far larger than their on-screen footprint. Tracking such a target
	through the screen-space path leaves the highlight frozen in place and sized
	to the canvas, so it is projected off the adornee's surface instead.
]]
const function findSurface(guiObject: GuiObject): (SurfaceGui?, BasePart?)
	local surfaceGui = guiObject:FindFirstAncestorWhichIsA("SurfaceGui")
	if surfaceGui == nil then
		return nil, nil
	end

	local adornee = surfaceGui.Adornee or surfaceGui.Parent
	if adornee ~= nil and adornee:IsA("BasePart") then
		return surfaceGui, adornee
	end

	return nil, nil
end

--- Local-space basis for each face a `SurfaceGui` can be mounted on, oriented
--- as the canvas is seen from outside the part: `right` follows increasing
--- canvas X, `up` follows decreasing canvas Y, and `normal` points outwards.
const FACE_BASES: { [Enum.NormalId]: { right: Vector3, up: Vector3, normal: Vector3 } } = {
	[Enum.NormalId.Front] = { right = Vector3.new(-1, 0, 0), up = Vector3.new(0, 1, 0), normal = Vector3.new(0, 0, -1) },
	[Enum.NormalId.Back] = { right = Vector3.new(1, 0, 0), up = Vector3.new(0, 1, 0), normal = Vector3.new(0, 0, 1) },
	[Enum.NormalId.Right] = { right = Vector3.new(0, 0, -1), up = Vector3.new(0, 1, 0), normal = Vector3.new(1, 0, 0) },
	[Enum.NormalId.Left] = { right = Vector3.new(0, 0, 1), up = Vector3.new(0, 1, 0), normal = Vector3.new(-1, 0, 0) },
	[Enum.NormalId.Top] = { right = Vector3.new(1, 0, 0), up = Vector3.new(0, 0, -1), normal = Vector3.new(0, 1, 0) },
	[Enum.NormalId.Bottom] = { right = Vector3.new(1, 0, 0), up = Vector3.new(0, 0, 1), normal = Vector3.new(0, -1, 0) },
}

--- Projects the patch of `adornee`'s surface covered by `guiObject`.
--- Returns `nil` when the surface is not facing the camera.
const function projectSurfaceRect(camera: Camera, guiObject: GuiObject, surfaceGui: SurfaceGui, adornee: BasePart): Rect?
	local canvas = surfaceGui.AbsoluteSize
	if canvas.X <= 0 or canvas.Y <= 0 then
		return nil
	end

	local basis = FACE_BASES[surfaceGui.Face]
	if basis == nil then
		return nil
	end

	-- Canvas-relative bounds, normalised so the surface can be sampled by UV.
	local offset = guiObject.AbsolutePosition - surfaceGui.AbsolutePosition
	local minU = offset.X / canvas.X
	local minV = offset.Y / canvas.Y
	local maxU = (offset.X + guiObject.AbsoluteSize.X) / canvas.X
	local maxV = (offset.Y + guiObject.AbsoluteSize.Y) / canvas.Y

	local size = adornee.Size
	local width = math.abs(basis.right:Dot(size))
	local height = math.abs(basis.up:Dot(size))
	local depth = basis.normal * (math.abs(basis.normal:Dot(size)) / 2)

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local visible = false

	for _, uv in { Vector2.new(minU, minV), Vector2.new(maxU, minV), Vector2.new(minU, maxV), Vector2.new(maxU, maxV) } do
		local local_ = basis.right * ((uv.X - 0.5) * width) + basis.up * ((0.5 - uv.Y) * height) + depth
		local point = camera:WorldToScreenPoint(adornee.CFrame:PointToWorldSpace(local_))

		if point.Z > MIN_DEPTH then
			visible = true

			minX = math.min(minX, point.X)
			minY = math.min(minY, point.Y)
			maxX = math.max(maxX, point.X)
			maxY = math.max(maxY, point.Y)
		end
	end

	if not visible then
		return nil
	end

	return {
		position = Vector2.new(minX, minY),
		size = Vector2.new(maxX - minX, maxY - minY),
		rotation = 0,
	}
end

--[[
	Tracks `target` and returns a source holding its screen rect.

	Must be called within a stable scope. All connections are registered with
	`cleanup()` and are torn down when the target changes or the scope dies.
]]
const function useTargetRect(target: () -> Target?): () -> Rect?
	local rect = source(nil :: Rect?)

	effect(function()
		local current = target()

		if current == nil then
			rect(nil)
			return
		end

		-- Clearing on destroy keeps a stale rect from pinning the highlight to
		-- wherever a removed instance happened to be.
		cleanup(current.Destroying:Connect(function()
			rect(nil)
		end))

		local surfaceGui: SurfaceGui? = nil
		local adornee: BasePart? = nil

		if not isWorldTarget(current) and current:IsA("GuiObject") then
			surfaceGui, adornee = findSurface(current :: GuiObject)
		end

		if isWorldTarget(current) or surfaceGui ~= nil then
			local camera = workspace.CurrentCamera
			if camera == nil then
				rect(nil)
				return
			end

			-- Model bounding boxes are comparatively expensive, so the last
			-- result is reused until the model actually moves or resizes.
			local lastCameraCFrame: CFrame? = nil
			local lastTargetCFrame: CFrame? = nil
			local lastTargetSize: Vector3? = nil

			local function update()
				-- Surface targets depend on the GuiObject's canvas rect as well
				-- as the part, so they are reprojected rather than cached.
				if surfaceGui ~= nil then
					rect(projectSurfaceRect(camera, current :: GuiObject, surfaceGui, adornee :: BasePart))
					return
				end

				local cframe, size = getWorldBounds(current)
				if cframe == nil or size == nil then
					rect(nil)
					return
				end

				local cameraCFrame = camera.CFrame

				-- Nothing moved, so the previous projection still holds.
				if cameraCFrame == lastCameraCFrame and cframe == lastTargetCFrame and size == lastTargetSize then
					return
				end

				lastCameraCFrame = cameraCFrame
				lastTargetCFrame = cframe
				lastTargetSize = size

				rect(projectBounds(camera, cframe, size))
			end

			update()

			cleanup(RunService.RenderStepped:Connect(update))
		else
			local guiObject = current :: GuiObject

			local function update()
				rect({
					position = guiObject.AbsolutePosition,
					size = guiObject.AbsoluteSize,
					rotation = guiObject.AbsoluteRotation,
				})
			end

			update()

			-- GuiObjects report their own layout changes, so there is no need
			-- to poll them every frame the way world targets require.
			cleanup(guiObject:GetPropertyChangedSignal("AbsolutePosition"):Connect(update))
			cleanup(guiObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
			cleanup(guiObject:GetPropertyChangedSignal("AbsoluteRotation"):Connect(update))
		end
	end)

	return rect
end

return {
	useTargetRect = useTargetRect,
	getGuiInset = getGuiInset,
	isWorldTarget = isWorldTarget,
}
