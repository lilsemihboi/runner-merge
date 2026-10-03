--[[
	RunnerManager
	=====================================
	The single client-side authority for ALL runner simulation. There is no
	server Heartbeat and no physics replication: the server only broadcasts
	each plot's roster + startClock ("start" signal) and this manager
	simulates every car locally inside ONE Heartbeat loop.

	Server -> client (Networker dispatch):
		setRunners(plotId, owner, runners, startClock, gateCount, runnerSpeedLevel, carSpeedMultiplier, routeId, selectedTrail, rev)
		applyRunnerDelta(plotId, baseRev, rev, removedIds, upserts, scalars)
		removePlot(plotId)
	Client -> server:
		fetch("requestState") -- late-join sync
		fetch("requestPlot", plotId) -- recovery when a delta revision gap is detected
		fire("reportGate", plotId, runnerId, gateId) -- owner gate crossings
		fire("reportLap", plotId, runnerId)

	Cars are addressed by their stable runner id, never by array slot: the
	roster is rewritten on every merge, and only the cars actually involved
	may appear, disappear or change level.

	Task 2: updateReplication() culls other players' plots by bounds. The
	local player's own plot is ALWAYS simulated; other plots only while the
	local character stands within that plot's runway bounds.
]]

local RunnerManager = {}
RunnerManager.__index = RunnerManager

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Configuration = require(ReplicatedStorage.Shared.Modules.Game.Configuration)
local FormatCurrency = require(ReplicatedStorage.Shared.Modules.Ui.FormatCurrency)
local FriendServiceClient = require(ReplicatedStorage.Shared.Services.FriendService.FriendServiceClient)
local GetDataSource = require(ReplicatedStorage.Shared.Modules.Ui.Sources.GetDataSource)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local MergeEffects = require(script.Parent.MergeEffects)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PathData = require(ReplicatedStorage.Shared.Classes.Runner.PathData)
local RouteServiceUtils = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceUtils)
local RunnerClient = require(ReplicatedStorage.Shared.Classes.Runner.RunnerClient)
local RunnerServiceTypes = require(ReplicatedStorage.Shared.Services.RunnerService.RunnerServiceTypes)
local RunnerUtils = require(script.Parent.RunnerUtils)
local SoundServiceClient = require(ReplicatedStorage.Shared.Services.SoundService.SoundServiceClient)
local Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)

local BOUNDS_CHECK_INTERVAL = 0.2
local PATH_RETRY_INTERVAL = 1
local RESYNC_RETRY_INTERVAL = 1
local INCOME_INDICATOR_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)

local function getTrailMultiplier(trailId: number?): number
	local trail = if trailId then Trails[trailId] else nil
	return if trail then trail.trailMultiplier else 1
end

-- One received entry, normalized into a fresh table so later roster writes
-- can never mutate a value some car already uses.
local function toRunnerEntry(entry: any): RunnerUtils.RunnerEntry?
	if typeof(entry) ~= "table" or typeof(entry.id) ~= "number" or typeof(entry.level) ~= "number" or typeof(entry.phase) ~= "number" then
		return nil
	end

	return { id = entry.id, level = entry.level, phase = entry.phase % 1 }
end

local function normalizeRev(value: any): number?
	return if typeof(value) == "number" and value % 1 == 0 then value else nil
end

function RunnerManager.new(): RunnerManager
	local selectedTrailAtom = GetDataSource("selectedTrail")
	local trailsVisibleAtom = GetDataSource({ "settings", "trails" })
	local self = setmetatable({
		runners = {},
		plots = {},
		resyncInFlight = {},
		plotGeneration = {},
		pendingRev = {},
		boundsCooldown = 0,
		multiplier = 1,
		janitor = Janitor.new(),
		cashMultiplierAtom = GetDataSource("cashMultiplier"),
		customMultiplierAtom = GetDataSource("customMultiplier"),
		shouldShowIndicator = GetDataSource({ "settings", "moneyIndicator" }),
		selectedTrailAtom = selectedTrailAtom,
		trailsVisibleAtom = trailsVisibleAtom,
		trailMultiplier = getTrailMultiplier(selectedTrailAtom()),
		vipMultiplier = 1,
		doubleCashMultiplier = 1,
	}, RunnerManager) :: RunnerManager

	self.networker = Networker.client.new("RunnerService", self :: any)
	self:start()

	local function updateMultiplier(new: number)
		self.multiplier = RunnerUtils.getCashBonusMultiplier(new)
	end

	local cashBonus = GetDataSource({ "upgrades", "cashBonus" })

	updateMultiplier(cashBonus())

	self.janitor:Add(Charm.subscribe(cashBonus, function(new)
		updateMultiplier(new)
	end))

	self.janitor:Add(Charm.subscribe(selectedTrailAtom, function(newTrailId)
		self.trailMultiplier = getTrailMultiplier(newTrailId)
	end))

	self.janitor:Add(Charm.subscribe(trailsVisibleAtom, function(isVisible)
		for _, cars in self.runners do
			for _, car in cars do
				car:setTrailsVisible(isVisible ~= false)
			end
		end
	end))

	task.spawn(function()
		-- A fetch response travels on a different channel than live broadcasts,
		-- so remember which plot registrations were already removed when the
		-- request left; a response for one of them is stale even if it arrives
		-- after the removal and must not resurrect the plot.
		local generationAtRequest = table.clone(self.plotGeneration)

		local snapshots: { RunnerServiceTypes.RunnerPlotSnapshot } = self.networker:fetch("requestState")
		if typeof(snapshots) ~= "table" then
			return
		end

		for _, snapshot in snapshots do
			if (generationAtRequest[snapshot.plotId] or 0) ~= (self.plotGeneration[snapshot.plotId] or 0) then
				continue
			end

			-- live broadcasts may already have arrived while fetching; the
			-- revision decides which state is newer, in either direction
			local state = self.plots[snapshot.plotId]
			if state and typeof(snapshot.rev) == "number" and snapshot.rev <= state.rev then
				continue
			end

			self:setRunners(
				snapshot.plotId,
				snapshot.owner,
				snapshot.runners,
				snapshot.startClock,
				snapshot.gateCount,
				snapshot.runnerSpeedLevel,
				snapshot.carSpeedMultiplier,
				snapshot.routeId,
				snapshot.selectedTrail,
				snapshot.rev
			)

			-- A delta received while this request was in flight may be newer
			-- than the snapshot; ask again while we are still behind it.
			local current = self.plots[snapshot.plotId]
			if current and current.rev < (self.pendingRev[snapshot.plotId] or 0) then
				self:_requestPlotResync(snapshot.plotId)
			end
		end
	end)

	return self
end

function RunnerManager.start(self: RunnerManager)
	if self.updateConn then
		return
	end

	self.updateConn = RunService.Heartbeat:Connect(function(dt)
		self:update(dt)
	end)
end

function RunnerManager.stop(self: RunnerManager)
	if self.updateConn then
		self.updateConn:Disconnect()
		self.updateConn = nil
	end
end

-- Server "start" signal: full roster snapshot for one plot. Reconciles the
-- RunnerClient pool by id (create / updateLevel / configure / destroy)
-- instead of rebuilding it, so a car that is still on the roster keeps
-- running exactly where it already was.
function RunnerManager.setRunners(
	self: RunnerManager,
	plotId: number,
	owner: Player,
	runners: { RunnerUtils.RunnerEntry },
	startClock: number,
	gateCount: number,
	runnerSpeedLevel: number,
	carSpeedMultiplier: number,
	routeId: number,
	selectedTrail: number?,
	rev: number
): ()
	local state = self.plots[plotId]
	if state and typeof(rev) == "number" and rev <= state.rev then
		-- an older snapshot must never overwrite a newer applied delta
		return
	end

	if not state then
		state = {
			plotId = plotId,
			owner = owner,
			runners = {},
			startClock = startClock,
			gateCount = gateCount,
			runnerSpeedLevel = runnerSpeedLevel,
			carSpeedMultiplier = carSpeedMultiplier,
			active = owner == Players.LocalPlayer,
			routeId = routeId,
			selectedTrail = selectedTrail,
			rev = 0,
		}
		self.plots[plotId] = state
		self.runners[plotId] = {}
	else
		state.owner = owner
		state.startClock = startClock
		state.gateCount = gateCount
		state.runnerSpeedLevel = runnerSpeedLevel
		state.carSpeedMultiplier = carSpeedMultiplier
		state.routeId = routeId
		state.selectedTrail = selectedTrail
		table.clear(state.runners)
	end

	if typeof(runners) == "table" then
		for _, entry in ipairs(runners) do
			local normalized = toRunnerEntry(entry)
			if normalized then
				state.runners[normalized.id] = normalized
			end
		end
	end

	-- A full snapshot is authoritative: whatever it contains may be shown.
	state.mergeHidden = nil
	state.mergeHiddenUntil = nil

	self:_reconcileCars(state)

	-- Advance the revision only once the roster has actually been applied: if
	-- anything above errors, the next delta's `baseRev` will not match and the
	-- client recovers with a fresh snapshot instead of silently staying stale.
	local newRev = normalizeRev(rev)
	if newRev then
		state.rev = newRev
	end
	if newRev and newRev > (self.pendingRev[plotId] or 0) then
		self.pendingRev[plotId] = newRev
	end
end

--[=[
	Server "diff" signal: only the cars/scalars that changed since `baseRev`.

	Revisions are chained, so a client whose state is not at `baseRev` knows it
	missed a message and asks for a full snapshot instead of silently drifting
	forever.
]=]
function RunnerManager.applyRunnerDelta(
	self: RunnerManager,
	plotId: number,
	baseRev: number,
	rev: number,
	removedIds: { number },
	upserts: { RunnerUtils.RunnerEntry },
	scalars: RunnerServiceTypes.RunnerPlotScalars?
): ()
	local normalizedBase = normalizeRev(baseRev)
	local normalizedRev = normalizeRev(rev)
	if typeof(plotId) ~= "number" or normalizedBase == nil or normalizedRev == nil then
		return
	end
	baseRev = normalizedBase
	rev = normalizedRev

	-- Remember the highest revision ever seen for this plot: a full snapshot
	-- generated before this delta must not satisfy a gap it did not cover.
	if rev > (self.pendingRev[plotId] or 0) then
		self.pendingRev[plotId] = rev
	end

	local state = self.plots[plotId]
	if not state then
		self:_requestPlotResync(plotId)
		return
	end

	if rev <= state.rev then
		return
	end

	if baseRev ~= state.rev then
		self:_requestPlotResync(plotId)
		return
	end

	-- A delta is only ever sent while no merge effect is active server-side:
	-- it is the authoritative "effect is over" signal, so hidden sources can
	-- always be shown again.
	state.mergeHidden = nil
	state.mergeHiddenUntil = nil

	if typeof(removedIds) == "table" then
		for _, runnerId in removedIds do
			if typeof(runnerId) == "number" then
				state.runners[runnerId] = nil
			end
		end
	end

	if typeof(upserts) == "table" then
		for _, entry in upserts do
			local normalized = toRunnerEntry(entry)
			if normalized then
				state.runners[normalized.id] = normalized
			end
		end
	end

	if typeof(scalars) == "table" then
		if typeof(scalars.startClock) == "number" then
			state.startClock = scalars.startClock
		end
		if typeof(scalars.runnerSpeedLevel) == "number" then
			state.runnerSpeedLevel = scalars.runnerSpeedLevel
		end
		if typeof(scalars.carSpeedMultiplier) == "number" then
			state.carSpeedMultiplier = scalars.carSpeedMultiplier
		end
		if typeof(scalars.gateCount) == "number" then
			state.gateCount = scalars.gateCount
		end
		if typeof(scalars.routeId) == "number" then
			state.routeId = scalars.routeId
		end
		if scalars.selectedTrailChanged == true then
			state.selectedTrail = scalars.selectedTrail
		end
	end

	self:_reconcileCars(state)

	-- Advance only after a successful apply; a mid-apply error leaves the old
	-- revision so the next message is detected as a gap and triggers a resync.
	state.rev = rev
end

--[=[
	Asks the server for a fresh full snapshot of one plot. Used when a delta
	arrives for an unknown plot or when a revision gap is detected, so a single
	missed message can never permanently desync a client.
]=]
function RunnerManager._requestPlotResync(self: RunnerManager, plotId: number): ()
	if self.resyncInFlight[plotId] then
		return
	end
	self.resyncInFlight[plotId] = true

	local generation = self.plotGeneration[plotId] or 0

	task.spawn(function()
		local ok, snapshot = pcall(function()
			return self.networker:fetch("requestPlot", plotId)
		end)

		self.resyncInFlight[plotId] = nil

		-- the plot may have been removed while the response was in flight
		if (self.plotGeneration[plotId] or 0) ~= generation then
			return
		end

		if ok and typeof(snapshot) == "table" then
			self:setRunners(
				snapshot.plotId,
				snapshot.owner,
				snapshot.runners,
				snapshot.startClock,
				snapshot.gateCount,
				snapshot.runnerSpeedLevel,
				snapshot.carSpeedMultiplier,
				snapshot.routeId,
				snapshot.selectedTrail,
				snapshot.rev
			)

			-- A delta seen while this fetch was in flight may be newer than the
			-- snapshot the server generated for us; ask again while we are
			-- still behind the newest revision we know about.
			local current = self.plots[plotId]
			if current and current.rev < (self.pendingRev[plotId] or 0) then
				self:_requestPlotResync(plotId)
			end
			return
		end

		local state = self.plots[plotId]
		if not state then
			return
		end

		task.delay(RESYNC_RETRY_INTERVAL, function()
			if self.plots[plotId] == state and (self.plotGeneration[plotId] or 0) == generation then
				self:_requestPlotResync(plotId)
			end
		end)
	end)
end

function RunnerManager.removePlot(self: RunnerManager, plotId: number): ()
	local cars = self.runners[plotId]
	if cars then
		for _, car in cars do
			car:destroy()
		end
	end

	self.runners[plotId] = nil
	self.plots[plotId] = nil
	self.resyncInFlight[plotId] = nil
	self.pendingRev[plotId] = nil
	self.plotGeneration[plotId] = (self.plotGeneration[plotId] or 0) + 1
end

-- Creates / updates / destroys cars so the pool matches `state.runners`
-- exactly. Lane, phase and level all come from the car's own entry, so a
-- reconcile that changes nothing never moves anything.
function RunnerManager._reconcileCars(self: RunnerManager, state: PlotState): ()
	local plotId = state.plotId
	local laneCount = PathData.getLaneCount(plotId)
	if laneCount <= 0 then
		-- plot geometrisi henüz replicate olmamış olabilir
		self:_schedulePathRetry(state)
		return
	end

	local isOwner = state.owner == Players.LocalPlayer
	local cars = self.runners[plotId]
	if not cars then
		cars = {}
		self.runners[plotId] = cars
	end

	local trailsVisible = self.trailsVisibleAtom() ~= false
	local hidden = state.mergeHidden
	if hidden and workspace:GetServerTimeNow() >= (state.mergeHiddenUntil or 0) then
		-- The effect is over even if no message arrived (e.g. the effect ran
		-- while this plot was out of bounds): show the cars again.
		state.mergeHidden = nil
		state.mergeHiddenUntil = nil
		hidden = nil
	end

	for runnerId, car in cars do
		if not state.runners[runnerId] then
			car:destroy()
			cars[runnerId] = nil
		end
	end

	for runnerId, entry in state.runners do
		local lane = RunnerUtils.getRunnerLane(plotId, runnerId, laneCount)
		local path = PathData.get(plotId, lane)
		if not path or path.length <= 0 then
			continue
		end

		local shouldShow = hidden == nil or hidden[runnerId] ~= true
		local car = cars[runnerId]

		if car then
			car.isOwner = isOwner
			car:setTrailsVisible(trailsVisible)
			-- configure before updateLevel: the new phase/clock are applied
			-- first, so a level change creates its replacement model at the
			-- final position instead of the pre-change one.
			car:configure(state.startClock, entry.phase, state.gateCount, state.runnerSpeedLevel, state.carSpeedMultiplier, path, state.selectedTrail)
			car:updateLevel(entry.level)
			car:setVisible(shouldShow)
		else
			local newCar = RunnerClient.new({
				plotId = plotId,
				runnerId = runnerId,
				level = entry.level,
				path = path,
				startClock = state.startClock,
				phase = entry.phase,
				gateCount = state.gateCount,
				runnerSpeedLevel = state.runnerSpeedLevel,
				isOwner = isOwner,
				active = state.active,
				carSpeedMultiplier = state.carSpeedMultiplier,
				selectedTrail = state.selectedTrail,
				trailsVisible = trailsVisible,
			})
			cars[runnerId] = newCar

			if not shouldShow then
				newCar:setVisible(false)
			end
		end
	end
end

function RunnerManager.playMergeEffect(self: RunnerManager, plotId: number, operations: { RunnerServiceTypes.MergeOperation }, duration: number?): ()
	local state = self.plots[plotId]
	if not state or not state.active or #operations == 0 then
		return
	end

	local sourceCFrames: { [number]: CFrame } = {}
	local cars = self.runners[plotId]
	if cars then
		for _, operation in ipairs(operations) do
			for _, source in { operation.leftSource, operation.rightSource } do
				local runnerId = source.runnerId
				if runnerId and not sourceCFrames[runnerId] then
					local runner = cars[runnerId]
					if runner and runner.model then
						sourceCFrames[runnerId] = runner.model:GetPivot()
					end
				end
			end
		end

		for runnerId in sourceCFrames do
			local runner = cars[runnerId]
			if runner then
				runner:setVisible(false)
			end
		end
	end

	-- While the effect runs, reconciles must not re-show the source cars (a
	-- resync snapshot or a path retry can land mid-animation). Expiry is
	-- timestamp-based and authoritative messages (delta/snapshot) also clear
	-- it, so a car can never stay hidden because a timer raced a message.
	state.mergeHidden = state.mergeHidden or {}
	for runnerId in sourceCFrames do
		state.mergeHidden[runnerId] = true
	end

	local effectDuration = if typeof(duration) == "number" and duration > 0 then duration else 0
	local hiddenUntil = workspace:GetServerTimeNow() + effectDuration
	if hiddenUntil > (state.mergeHiddenUntil or 0) then
		state.mergeHiddenUntil = hiddenUntil
	end

	MergeEffects.play(plotId, operations, sourceCFrames)
end

function RunnerManager._schedulePathRetry(self: RunnerManager, state: PlotState): ()
	if state.pathRetryScheduled then
		return
	end

	state.pathRetryScheduled = true
	task.delay(PATH_RETRY_INTERVAL, function()
		state.pathRetryScheduled = false
		if self.plots[state.plotId] ~= state then
			return
		end

		self:_reconcileCars(state)
	end)
end

function RunnerManager._getPlotBounds(_self: RunnerManager, state: PlotState): (CFrame?, Vector3?)
	if state.boundsCf and state.boundsSize then
		return state.boundsCf, state.boundsSize
	end

	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	local plotModel = if plotsFolder then plotsFolder:FindFirstChild(tostring(state.plotId)) else nil
	if not plotModel or not plotModel:IsA("Model") then
		return nil, nil
	end

	local boundsCf: CFrame
	local boundsSize: Vector3

	local runwayModel = plotModel:FindFirstChild(`Runway`)
	if runwayModel and runwayModel:IsA("Model") then
		boundsCf, boundsSize = runwayModel:GetBoundingBox()
	else
		boundsCf, boundsSize = plotModel:GetBoundingBox()
	end

	state.boundsCf = boundsCf
	state.boundsSize = boundsSize

	return boundsCf, boundsSize
end

function RunnerManager._isWithinPlotBounds(self: RunnerManager, state: PlotState, position: Vector3): boolean
	local boundsCf, boundsSize = self:_getPlotBounds(state)
	if not boundsCf or not boundsSize then
		return false
	end

	local padding = Configuration.RUNNER_BOUNDS_PADDING
	local relativePos = boundsCf:PointToObjectSpace(position)

	return math.abs(relativePos.X) <= boundsSize.X / 2 + padding and math.abs(relativePos.Z) <= boundsSize.Z / 2 + padding
end

function RunnerManager._getGateAttachment(_self: RunnerManager, plotId: number, gateId: number): Attachment?
	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	local plotModel = if plotsFolder then plotsFolder:FindFirstChild(tostring(plotId)) else nil
	local runwayModel = if plotModel then plotModel:FindFirstChild(`Runway`) else nil
	local gateAttachments = if runwayModel then runwayModel:FindFirstChild("gateAttachments") else nil
	local attachment = if gateAttachments then gateAttachments:FindFirstChild(tostring(gateId)) else nil

	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	return nil
end

function RunnerManager._getIncomeIndicatorGui(self: RunnerManager, plotId: number, gateId: number): BillboardGui?
	local attachment = self:_getGateAttachment(plotId, gateId)
	if not attachment then
		return nil
	end

	local billboardGui = attachment:FindFirstChild("IncomeIndicator")
	if billboardGui and billboardGui:IsA("BillboardGui") then
		return billboardGui
	end

	billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "IncomeIndicator"
	billboardGui.Adornee = attachment
	billboardGui.AlwaysOnTop = true
	billboardGui.LightInfluence = 0
	billboardGui.Size = UDim2.fromScale(2, 2)
	billboardGui.MaxDistance = 150
	billboardGui.Parent = attachment

	return billboardGui
end

function RunnerManager._showIncomeIndicator(self: RunnerManager, plotId: number, gateId: number, incomePerLap: number, routeId: number): ()
	local billboardGui = self:_getIncomeIndicatorGui(plotId, gateId)
	if not billboardGui then
		return
	end
	local route = RouteServiceUtils[routeId]
	local isExclusive = route ~= nil and gateId > route.cashGateCap

	local textLabel = Instance.new("TextLabel")
	textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.Position = UDim2.fromScale(0.5, 0.5)
	textLabel.Size = UDim2.new(0, 0, 0, 0)
	textLabel.Text = `+${FormatCurrency(
		math.max(
			0,
			math.round(
				incomePerLap
					* self.multiplier
					* (1 + (FriendServiceClient.friendCount() * Configuration.FRIENDS_PER_TICK / 100))
					* self.cashMultiplierAtom()
					* self.customMultiplierAtom()
					* self.vipMultiplier
					* self.doubleCashMultiplier
					* self.trailMultiplier
					* route.cashMultiplier
			)
		),
		false
	)}`
	textLabel.TextColor3 = if isExclusive then Color3.fromRGB(255, 221, 89) else Color3.fromRGB(70, 255, 120)
	textLabel.TextScaled = false
	textLabel.TextSize = 36
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 80, 30)
	textLabel.TextStrokeTransparency = 0.2
	textLabel.Parent = billboardGui

	local offsetX = math.random(-10, 20) / 10
	local offsetY = math.random(-10, 20) / 10
	local offsetZ = math.random(-10, 20) / 10
	billboardGui.StudsOffset = Vector3.new(offsetX, offsetY, offsetZ)

	textLabel:TweenSize(UDim2.fromScale(2, 2), Enum.EasingDirection.InOut, Enum.EasingStyle.Quint, 0.3)

	task.delay(0.3, function()
		if not billboardGui.Parent or not textLabel.Parent then
			return
		end

		TweenService:Create(billboardGui, INCOME_INDICATOR_TWEEN_INFO, {
			StudsOffset = billboardGui.StudsOffset + Vector3.new(0, 1, 0),
		}):Play()

		TweenService:Create(textLabel, INCOME_INDICATOR_TWEEN_INFO, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end)

	Debris:AddItem(textLabel, 0.6)
end

-- Task 2: replication culling. Own plot is always active; other players'
-- plots are only simulated while the local character is inside their bounds.
function RunnerManager.updateReplication(self: RunnerManager): ()
	local character = Players.LocalPlayer.Character
	local position = if character then character:GetPivot().Position else nil

	for plotId, state in self.plots do
		local isOwner = state.owner == Players.LocalPlayer
		local withinBounds = position ~= nil and self:_isWithinPlotBounds(state, position :: Vector3)
		local active = isOwner or withinBounds

		if state.active == active then
			continue
		end

		state.active = active

		local cars = self.runners[plotId]
		if cars then
			for _, car in cars do
				car:setActive(active)
			end
		end
	end
end

function RunnerManager.update(self: RunnerManager, dt: number): ()
	self.boundsCooldown -= dt
	if self.boundsCooldown <= 0 then
		self.boundsCooldown = BOUNDS_CHECK_INTERVAL
		self:updateReplication()
	end

	local now = workspace:GetServerTimeNow()
	for plotId, cars in self.runners do
		local state = self.plots[plotId]
		if not state or not state.active then
			continue
		end

		for _, car in cars do
			local crossedGates, lapsCompleted = car:update(now)
			if crossedGates then
				for _, gateId in crossedGates do
					if self.shouldShowIndicator() then
						self:_showIncomeIndicator(plotId, gateId, car.incomePerLap, state.routeId)
					end
					SoundServiceClient:play("moneyPickup")
					self.networker:fire("reportGate", plotId, car.runnerId, gateId)
				end
			end

			if lapsCompleted > 0 then
				self.networker:fire("reportLap", plotId, car.runnerId)
			end
		end
	end
end

function RunnerManager.destroy(self: RunnerManager): ()
	self.networker:destroy()
	self:stop()

	for plotId in self.plots do
		self:removePlot(plotId)
	end
end

type PlotState = {
	plotId: number,
	owner: Player,
	runners: { [number]: RunnerUtils.RunnerEntry },
	startClock: number,
	gateCount: number,
	routeId: number,
	runnerSpeedLevel: number,
	active: boolean,
	carSpeedMultiplier: number,
	selectedTrail: number?,
	rev: number,
	mergeHidden: { [number]: boolean }?,
	mergeHiddenUntil: number?,
	boundsCf: CFrame?,
	boundsSize: Vector3?,
	pathRetryScheduled: boolean?,
}

export type RunnerManager = typeof(setmetatable(
	{} :: {
		runners: { [number]: { [number]: RunnerClient.Runner } },
		plots: { [number]: PlotState },
		resyncInFlight: { [number]: boolean },
		plotGeneration: { [number]: number },
		pendingRev: { [number]: number },
		networker: Networker.Client,
		updateConn: RBXScriptConnection?,
		boundsCooldown: number,
		janitor: Janitor.Janitor,
		multiplier: number,
		cashMultiplierAtom: Charm.Atom<number>,
		shouldShowIndicator: Charm.Atom<boolean>,
		customMultiplierAtom: Charm.Atom<number>,
		selectedTrailAtom: Charm.Atom<number?>,
		trailsVisibleAtom: Charm.Atom<boolean>,
		trailMultiplier: number,
		vipMultiplier: number,
		doubleCashMultiplier: number,
	},
	RunnerManager
))

return RunnerManager
