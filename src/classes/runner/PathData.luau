--!nonstrict
--[[
	PathData
	=====================================
	Static Catmull-Rom path cache shared by every runner (client + server).
	The path for a plot+route is computed ONCE from the Runway waypoint
	attachments and reused by all cars on that plot:
		- points: densely sampled Catmull-Rom polyline
		- upVectors: densely sampled waypoint orientation
		- cumulative: arc-length lookup table (cumulative[i] = distance from start to points[i])
		- length: total arc length
		- gateDistances: arc distance of every gate attachment projected onto the path

	PathData.sample resolves distance -> CFrame with a binary
	search over the cumulative table (O(log n) instead of a linear scan).

	Only one route is ever active per plot at a time, so the cache is a
	single slot per plot keyed by routeId: switching routes invalidates and
	rebuilds rather than keeping every route's data cached simultaneously.
]]

local PathData = {}

local SAMPLES_PER_SEGMENT = 12
local DIRECTION_EPSILON = 1e-4
local CATMULL_ROM_ALPHA = 0.5

local cache: { [number]: { runwayModel: Instance, laneCount: number, lanes: { [number]: Path } } } = {}

local function getLaneFolders(runwayModel: Instance): { Folder }
	local waypointsFolder = runwayModel:FindFirstChild("waypoints")
	if not waypointsFolder then
		return {}
	end

	local laneFolders: { Folder } = {}

	for _, child in waypointsFolder:GetChildren() do
		if child:IsA("Folder") and child.Name:match("^lane%d+$") then
			table.insert(laneFolders, child)
		end
	end

	table.sort(laneFolders, function(a: Folder, b: Folder)
		local aNum = tonumber(a.Name:match("%d+")) or 0
		local bNum = tonumber(b.Name:match("%d+")) or 0
		return aNum < bNum
	end)

	return laneFolders
end

local function getRunwayModel(plotId: number): Instance?
	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	if not plotsFolder then
		return nil
	end

	local plotModel = plotsFolder:FindFirstChild(tostring(plotId))
	if not plotModel then
		return nil
	end

	return plotModel:FindFirstChild(`Runway`)
end

local function getWaypointCFrames(laneFolder: Folder): { CFrame }
	local attachments: { Attachment } = {}
	for _, child in laneFolder:GetChildren() do
		if child:IsA("Attachment") then
			attachments[#attachments + 1] = child
		end
	end

	table.sort(attachments, function(firstAttachment: Attachment, secondAttachment: Attachment)
		local firstNumber = tonumber(firstAttachment.Name)
		local secondNumber = tonumber(secondAttachment.Name)
		if firstNumber and secondNumber then
			return firstNumber < secondNumber
		end
		return firstAttachment.Name < secondAttachment.Name
	end)

	local cframes: { CFrame } = {}
	for _, attachment in attachments do
		cframes[#cframes + 1] = attachment.WorldCFrame
	end

	return cframes
end

-- Invalidates the cached entry for plotId if the live Runway instance
-- differs from the one we last computed against (i.e. it was destroyed
-- and rebuilt since, whether for a route swap or anything else).
local function invalidateIfModelChanged(plotId: number, runwayModel: Instance?)
	local cached = cache[plotId]
	if cached and cached.runwayModel ~= runwayModel then
		cache[plotId] = nil
	end
end

function PathData.getLaneCount(plotId: number): number
	local runwayModel = getRunwayModel(plotId)
	invalidateIfModelChanged(plotId, runwayModel)

	local cached = cache[plotId]
	if cached then
		return cached.laneCount
	end

	if not runwayModel then
		return 0
	end

	local laneFolders = getLaneFolders(runwayModel)
	cache[plotId] = { runwayModel = runwayModel, laneCount = #laneFolders, lanes = {} }

	return #laneFolders
end

local function buildSmoothPath(waypoints: { CFrame }): ({ Vector3 }, { Vector3 })
	if #waypoints < 2 then
		local points = {}
		local upVectors = {}
		for _, waypoint in waypoints do
			points[#points + 1] = waypoint.Position
			upVectors[#upVectors + 1] = waypoint.UpVector
		end
		return points, upVectors
	end

	local sampledPath = {}
	local sampledUpVectors = {}

	for index = 1, #waypoints - 1 do
		local currentWaypoint = waypoints[index]
		local nextWaypoint = waypoints[index + 1]
		local currentPosition = currentWaypoint.Position
		local nextPosition = nextWaypoint.Position
		local previousPosition = if index > 1 then waypoints[index - 1].Position else currentPosition * 2 - nextPosition
		local futurePosition = if index + 2 <= #waypoints then waypoints[index + 2].Position else nextPosition * 2 - currentPosition

		local firstKnot = 0
		local secondKnot = firstKnot + (currentPosition - previousPosition).Magnitude ^ CATMULL_ROM_ALPHA
		local thirdKnot = secondKnot + (nextPosition - currentPosition).Magnitude ^ CATMULL_ROM_ALPHA
		local fourthKnot = thirdKnot + (futurePosition - nextPosition).Magnitude ^ CATMULL_ROM_ALPHA

		for step = 0, SAMPLES_PER_SEGMENT do
			local alpha = step / SAMPLES_PER_SEGMENT
			local knot = secondKnot + (thirdKnot - secondKnot) * alpha
			local firstPoint = previousPosition:Lerp(currentPosition, (knot - firstKnot) / (secondKnot - firstKnot))
			local secondPoint = currentPosition:Lerp(nextPosition, (knot - secondKnot) / (thirdKnot - secondKnot))
			local thirdPoint = nextPosition:Lerp(futurePosition, (knot - thirdKnot) / (fourthKnot - thirdKnot))
			local firstTangent = firstPoint:Lerp(secondPoint, (knot - firstKnot) / (thirdKnot - firstKnot))
			local secondTangent = secondPoint:Lerp(thirdPoint, (knot - secondKnot) / (fourthKnot - secondKnot))
			local catmullRomPoint = firstTangent:Lerp(secondTangent, alpha)
			sampledPath[#sampledPath + 1] = catmullRomPoint
			sampledUpVectors[#sampledUpVectors + 1] = currentWaypoint:Lerp(nextWaypoint, alpha).UpVector
		end
	end

	return sampledPath, sampledUpVectors
end
local function getPathDirection(points: { Vector3 }, index: number): Vector3
	local point = points[index]

	for nextIndex = index + 1, #points do
		local direction = points[nextIndex] - point
		if direction.Magnitude >= DIRECTION_EPSILON then
			return direction.Unit
		end
	end

	for previousIndex = index - 1, 1, -1 do
		local direction = point - points[previousIndex]
		if direction.Magnitude >= DIRECTION_EPSILON then
			return direction.Unit
		end
	end

	return Vector3.zAxis
end

local function getWorldUp(direction: Vector3): Vector3
	local up = Vector3.yAxis - direction * direction.Y
	if up.Magnitude < DIRECTION_EPSILON then
		local fallback = if math.abs(direction.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
		up = fallback - direction * direction:Dot(fallback)
	end

	return up.Unit
end

local function buildCumulative(points: { Vector3 }): ({ number }, number)
	local cumulative = table.create(#points)
	cumulative[1] = 0

	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
		cumulative[index] = total
	end

	return cumulative, total
end

local function projectOntoPath(points: { Vector3 }, cumulative: { number }, position: Vector3): number
	local bestDistanceSq = math.huge
	local bestArcDistance = 0

	for index = 2, #points do
		local fromPoint = points[index - 1]
		local segmentVector = points[index] - fromPoint
		local segmentLengthSq = segmentVector:Dot(segmentVector)

		local t = 0
		if segmentLengthSq > 1e-8 then
			t = math.clamp((position - fromPoint):Dot(segmentVector) / segmentLengthSq, 0, 1)
		end

		local closestPoint = fromPoint + segmentVector * t
		local offset = position - closestPoint
		local distanceSq = offset:Dot(offset)

		if distanceSq < bestDistanceSq then
			bestDistanceSq = distanceSq
			bestArcDistance = cumulative[index - 1] + math.sqrt(segmentLengthSq) * t
		end
	end

	return bestArcDistance
end

local function buildGateDistances(runwayModel: Instance, points: { Vector3 }, cumulative: { number }): { [number]: number }
	local gateDistances: { [number]: number } = {}

	local gateAttachments = runwayModel:FindFirstChild("gateAttachments")
	if not gateAttachments then
		return gateDistances
	end

	for _, attachment in gateAttachments:GetChildren() do
		if not attachment:IsA("Attachment") then
			continue
		end

		local gateId = tonumber(attachment.Name)
		if not gateId then
			continue
		end

		gateDistances[gateId] = projectOntoPath(points, cumulative, attachment.WorldCFrame.Position)
	end

	return gateDistances
end

function PathData.sample(path: Path, distance: number): CFrame
	local points = path.points
	local cumulative = path.cumulative
	local numPoints = #points

	if path.length <= 0 or numPoints < 2 then
		return CFrame.new(points[1] or Vector3.zero)
	end

	distance %= path.length

	local low, high = 2, numPoints
	while low < high do
		local mid = (low + high) // 2
		if cumulative[mid] < distance then
			low = mid + 1
		else
			high = mid
		end
	end

	local fromPoint = points[low - 1]
	local toPoint = points[low]
	local segmentLength = cumulative[low] - cumulative[low - 1]
	local segmentProgress = if segmentLength > 1e-4 then (distance - cumulative[low - 1]) / segmentLength else 0
	local position = fromPoint:Lerp(toPoint, segmentProgress)

	local direction = getPathDirection(points, low - 1)
	local up = path.upVectors[low - 1]:Lerp(path.upVectors[low], segmentProgress)
	up = up - direction * direction:Dot(up)
	if up.Magnitude < DIRECTION_EPSILON then
		up = getWorldUp(direction)
	end

	return CFrame.lookAt(position, position + direction, up.Unit)
end

function PathData.get(plotId: number, laneId: number?): Path?
	local lane = laneId or 1

	local runwayModel = getRunwayModel(plotId)
	invalidateIfModelChanged(plotId, runwayModel)

	local cached = cache[plotId]
	if cached and cached.lanes[lane] then
		return cached.lanes[lane]
	end

	if not runwayModel then
		return nil
	end

	local laneFolders = getLaneFolders(runwayModel)
	if not cached then
		cached = { runwayModel = runwayModel, laneCount = #laneFolders, lanes = {} }
		cache[plotId] = cached
	end

	local laneFolder = laneFolders[lane]
	if not laneFolder then
		return nil
	end

	local waypoints = getWaypointCFrames(laneFolder)
	local points, upVectors = buildSmoothPath(waypoints)
	if #points < 2 then
		return nil
	end

	local cumulative, length = buildCumulative(points)
	if length <= 0 then
		return nil
	end

	local path: Path = {
		points = points,
		upVectors = upVectors,
		cumulative = cumulative,
		length = length,
		gateDistances = buildGateDistances(runwayModel, points, cumulative),
	}
	cached.lanes[lane] = path

	return path
end

export type Path = {
	points: { Vector3 },
	upVectors: { Vector3 },
	cumulative: { number },
	length: number,
	gateDistances: { [number]: number },
}

return PathData
