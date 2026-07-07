--[[
	PathData
	=====================================
	Static Catmull-Rom path cache shared by every runner (client + server).
	The path for a plot is computed ONCE from the Runway waypoint attachments
	and reused by all cars on that plot:
		- points: densely sampled Catmull-Rom polyline
		- cumulative: arc-length lookup table (cumulative[i] = distance from start to points[i])
		- length: total arc length
		- gateDistances: arc distance of every gate attachment projected onto the path

	PathData.sample resolves distance -> (position, direction) with a binary
	search over the cumulative table (O(log n) instead of a linear scan).
]]

local PathData = {}

local SAMPLES_PER_SEGMENT = 12

local cache: { [number]: Path } = {}

local function getRunwayModel(plotId: number): Instance?
	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	if not plotsFolder then
		return nil
	end

	local plotModel = plotsFolder:FindFirstChild(tostring(plotId))
	if not plotModel then
		return nil
	end

	return plotModel:FindFirstChild("Runway")
end

local function getWaypointPositions(runwayModel: Instance): { Vector3 }
	local waypointsFolder = runwayModel:FindFirstChild("waypoints")
	if not waypointsFolder then
		return {}
	end

	local attachments: { Attachment } = {}
	for _, child in waypointsFolder:GetChildren() do
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

	local positions: { Vector3 } = {}
	for _, attachment in attachments do
		positions[#positions + 1] = attachment.WorldCFrame.Position
	end

	return positions
end

local function buildSmoothPath(positions: { Vector3 }): { Vector3 }
	if #positions < 2 then
		return positions
	end

	local sampledPath = {}

	for index = 1, #positions - 1 do
		local previousPosition = positions[math.max(1, index - 1)]
		local currentPosition = positions[index]
		local nextPosition = positions[index + 1]
		local futurePosition = positions[math.min(#positions, index + 2)]

		for step = 0, SAMPLES_PER_SEGMENT do
			local alpha = step / SAMPLES_PER_SEGMENT
			local catmullRomPoint = (
				0.5
				* (
					(2 * currentPosition)
					+ ((-previousPosition + nextPosition) * alpha)
					+ ((2 * previousPosition - 5 * currentPosition + 4 * nextPosition - futurePosition) * (alpha * alpha))
					+ ((-previousPosition + 3 * currentPosition - 3 * nextPosition + futurePosition) * (alpha * alpha * alpha))
				)
			)
			sampledPath[#sampledPath + 1] = catmullRomPoint
		end
	end

	return sampledPath
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

function PathData.get(plotId: number): Path?
	local cached = cache[plotId]
	if cached then
		return cached
	end

	local runwayModel = getRunwayModel(plotId)
	if not runwayModel then
		return nil
	end

	local points = buildSmoothPath(getWaypointPositions(runwayModel))
	if #points < 2 then
		return nil
	end

	local cumulative, length = buildCumulative(points)
	if length <= 0 then
		return nil
	end

	local path: Path = {
		points = points,
		cumulative = cumulative,
		length = length,
		gateDistances = buildGateDistances(runwayModel, points, cumulative),
	}
	cache[plotId] = path

	return path
end

function PathData.sample(path: Path, distance: number): (Vector3, Vector3)
	local points = path.points
	local cumulative = path.cumulative
	local numPoints = #points

	if path.length <= 0 or numPoints < 2 then
		return points[1] or Vector3.zero, Vector3.zAxis
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

	local direction = toPoint - fromPoint
	if direction.Magnitude < 1e-4 then
		-- Catmull-Rom emits duplicate points at segment joins; look ahead for a usable direction
		for index = low + 1, numPoints do
			direction = points[index] - fromPoint
			if direction.Magnitude >= 1e-4 then
				break
			end
		end
	end

	if direction.Magnitude < 1e-4 then
		direction = Vector3.zAxis
	end

	return position, direction.Unit
end

export type Path = {
	points: { Vector3 },
	cumulative: { number },
	length: number,
	gateDistances: { [number]: number },
}

return PathData
