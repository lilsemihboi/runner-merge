--[[
	RunnerService (server)
	=====================================
	Zero per-frame server load: NO Heartbeat, NO physics, NO models.
	The server only:
		1. Broadcasts each plot's runner roster + startClock ("start" signal)
		   whenever the runners array / gates upgrade / route changes (debounced).
		2. Authoritatively validates client gate-crossing reports on demand,
		   by recomputing the runner's deterministic progress from the shared
		   clock, and pays incomePerLap per validated gate crossing.

	Determinism contract (must match RunnerClient/RunnerManager exactly):
		travelTime = path.length / max(1, getRunnerSpeed(level, runnerSpeedLevel))
		lane       = getRunnerLane(plotId, runnerId, laneCount)
		phase      = entry.phase -- owned by the runner, never derived from the roster
		progress   = ((GetServerTimeNow() - startClock) / travelTime + phase) % 1
]]

local RunnerService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local FriendServiceServer = require(ServerScriptService.Services.FriendService.FriendServiceServer)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local MonetizationServiceServer = require(ServerScriptService.Services.MonetizationService.MonetizationServiceServer)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PathData = require(ReplicatedStorage.Shared.Classes.Runner.PathData)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RunnerServiceTypes = require(ReplicatedStorage.Shared.Services.RunnerService.RunnerServiceTypes)
local RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)
local Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)
const RouteServiceUtils = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceUtils)

-- a reported gate must have been passed within the last N seconds (covers ping + frame time)
local GATE_TOLERANCE_SECONDS = 2
-- same (runner, gate) pair can only be awarded once per ~lap
local LAP_COOLDOWN_RATIO = 0.85
local MERGE_INPUT_DURATION = 0.28
local MERGE_RESULT_DURATION = 0.42
local MERGE_ROOT_STAGGER = 0.12
local MERGE_EFFECT_TRAIL_DURATION = 0.2

local function getTrailMultiplier(trailId: number?): number
	local trail = if trailId then Trails[trailId] else nil
	return if trail then trail.trailMultiplier else 1
end

local function getMergeEffectDuration(operations: { RunnerServiceTypes.MergeOperation }): number
	local completionTimes: { [number]: number } = {}
	local rootCount = 0
	local latestCompletion = 0

	for _, operation in ipairs(operations) do
		local startTime = 0
		local hasDependency = false

		for _, source in { operation.leftSource, operation.rightSource } do
			if source.resultId then
				startTime = math.max(startTime, completionTimes[source.resultId] or 0)
				hasDependency = true
			end
		end

		if not hasDependency then
			startTime = rootCount * MERGE_ROOT_STAGGER
			rootCount += 1
		end

		local completionTime = startTime + MERGE_INPUT_DURATION + MERGE_RESULT_DURATION
		completionTimes[operation.id] = completionTime
		latestCompletion = math.max(latestCompletion, completionTime)
	end

	return latestCompletion + MERGE_EFFECT_TRAIL_DURATION
end

function RunnerService.init(self: RunnerService)
	self.plots = {}
	self.networker = Networker.server.new("RunnerService", self, {
		self.reportGate,
		self.requestState,
		self.reportLap,
	})
end

function RunnerService.registerPlot(self: RunnerService, player: Player, plotId: number)
	self:unregisterPlot(player)

	local profile = ProfileServiceServer.getProfile(player)
	local selectedTrail = profile:getSelectedTrail()
	local state: PlotState = {
		plotId = plotId,
		player = player,
		startClock = workspace:GetServerTimeNow(),
		gateAwards = {},
		lapClocks = {},
		janitor = Janitor.new(),
		broadcastScheduled = false,
		mergeEffectActive = false,
		mergeEffectId = 0,
		vipOwned = false,
		doubleCashOwned = false,
		doubleSpeedOwned = false,
		selectedTrail = selectedTrail,
		trailMultiplier = getTrailMultiplier(selectedTrail),
		clearGateAwardsOnBroadcast = false,
	}
	self.plots[plotId] = state

	state.janitor:Add(
		DataService:getArrayInsertedSignal(player, { "runners" }):Connect(function()
			self:_scheduleBroadcast(state)
		end),
		"Disconnect"
	)

	state.janitor:Add(
		DataService:getArrayRemovedSignal(player, { "runners" }):Connect(function()
			self:_scheduleBroadcast(state)
		end),
		"Disconnect"
	)

	state.janitor:Add(
		DataService:getChangedSignal(player, { "upgrades", "gates" }):Connect(function()
			self:_scheduleBroadcast(state)
		end),
		"Disconnect"
	)

	state.janitor:Add(
		DataService:getChangedSignal(player, { "extraGates" }):Connect(function()
			self:_scheduleBroadcast(state)
		end),
		"Disconnect"
	)

	state.janitor:Add(
		DataService:getChangedSignal(player, { "upgrades", "runnerSpeed" }):Connect(function()
			self:_scheduleBroadcast(state)
		end),
		"Disconnect"
	)

	state.janitor:Add(
		DataService:getChangedSignal(player, { "selectedTrail" }):Connect(function(newTrailId)
			state.selectedTrail = newTrailId
			state.trailMultiplier = getTrailMultiplier(newTrailId)
			self:_scheduleBroadcast(state, false)
		end),
		"Disconnect"
	)

	if MonetizationServiceServer:ownsGamepass(player, Products.vip) then
		self.networker:set(player, "vipMultiplier", 1.5)
		state.vipOwned = true
	end

	if MonetizationServiceServer:ownsGamepass(player, Products.x2Speed) then
		state.doubleSpeedOwned = true
	end

	if MonetizationServiceServer:ownsGamepass(player, Products.x2Cash) then
		self.networker:set(player, "doubleCashMultiplier", 2)
		state.doubleCashOwned = true
	end

	state.janitor:Add(MonetizationServiceServer:getPassOwnshipChanged(player, Products.x2Speed):Connect(function(owns)
		if owns then
			state.doubleSpeedOwned = true
			self:_broadcastPlot(state)
		end
	end))

	state.janitor:Add(MonetizationServiceServer:getPassOwnshipChanged(player, Products.x2Cash):Connect(function(owns)
		if owns then
			self.networker:set(player, "doubleCashMultiplier", 2)
			state.doubleCashOwned = true
		end
	end))

	state.janitor:Add(MonetizationServiceServer:getPassOwnshipChanged(player, Products.vip):Connect(function(owns)
		if owns then
			self.networker:set(player, "vipMultiplier", 1.5)
			state.vipOwned = true
		end
	end))

	self:_broadcastPlot(state)
end

function RunnerService.unregisterPlot(self: RunnerService, player: Player)
	for plotId, state in self.plots do
		if state.player ~= player then
			continue
		end

		state.janitor:Destroy()
		self.plots[plotId] = nil
		self.networker:fireAll("removePlot", plotId)
	end
end

function RunnerService._snapshot(_self: RunnerService, state: PlotState): RunnerServiceTypes.RunnerPlotSnapshot
	local profile = ProfileServiceServer.getProfile(state.player)

	return {
		plotId = state.plotId,
		owner = state.player,
		runners = RunnerUtils.sanitizeRunners(profile:getRunners()),
		startClock = state.startClock,
		gateCount = profile:getActiveGateCount(),
		runnerSpeedLevel = profile:getUpgradeLevel("runnerSpeed"),
		carSpeedMultiplier = state.doubleSpeedOwned and 2 or 1,
		routeId = profile:getRoute(),
		selectedTrail = state.selectedTrail,
	}
end

-- The single source of truth for a runner's deterministic movement, shared by
-- gate validation and lap accounting so both always agree with the client.
function RunnerService._getRunnerTiming(_self: RunnerService, state: PlotState, entry: RunnerUtils.RunnerEntry, runnerSpeedLevel: number): RunnerTiming?
	local laneCount = PathData.getLaneCount(state.plotId)
	local lane = RunnerUtils.getRunnerLane(state.plotId, entry.id, laneCount)
	local path = PathData.get(state.plotId, lane)
	if not path or path.length <= 0 then
		return nil
	end

	local doubleSpeedMultiplier = if state.doubleSpeedOwned then 2 else 1
	local speed = RunnerUtils.getRunnerSpeed(entry.level, runnerSpeedLevel) * doubleSpeedMultiplier

	return {
		path = path,
		speed = speed,
		travelTime = path.length / math.max(1, speed),
		phase = entry.phase,
	}
end

-- Anchors every runner to the lap boundary it has most recently passed.
-- Laps are credited from this anchor forward, so a roster/speed change can
-- never retroactively re-price the time already spent running: without this,
-- a faster travelTime would make the whole session recount as dozens of laps.
function RunnerService._anchorLapClocks(self: RunnerService, state: PlotState)
	local profile = ProfileServiceServer.getProfile(state.player)
	local entries = RunnerUtils.sanitizeRunners(profile:getRunners())
	local runnerSpeedLevel = profile:getUpgradeLevel("runnerSpeed")
	local now = workspace:GetServerTimeNow()
	local lapClocks: { [number]: number } = {}

	for _, entry in ipairs(entries) do
		local timing = self:_getRunnerTiming(state, entry, runnerSpeedLevel)
		if not timing then
			continue
		end

		-- keep the fraction of the current lap already run, drop nothing
		local lapProgress = ((now - state.startClock) / timing.travelTime + timing.phase) % 1
		lapClocks[entry.id] = now - lapProgress * timing.travelTime
	end

	state.lapClocks = lapClocks
end

-- merge() rewrites the whole array (many remove/insert signals in one frame);
-- defer so a burst collapses into a single broadcast.
function RunnerService._scheduleBroadcast(self: RunnerService, state: PlotState, clearGateAwards: boolean?)
	if state.mergeEffectActive or state.broadcastScheduled then
		if clearGateAwards ~= false then
			state.clearGateAwardsOnBroadcast = true
		end
		return
	end

	state.clearGateAwardsOnBroadcast = clearGateAwards ~= false
	state.broadcastScheduled = true
	task.defer(function()
		state.broadcastScheduled = false
		if self.plots[state.plotId] ~= state then
			return
		end

		local shouldClearGateAwards = state.clearGateAwardsOnBroadcast
		state.clearGateAwardsOnBroadcast = false
		self:_broadcastPlot(state, shouldClearGateAwards)
	end)
end

function RunnerService.resetForRouteChange(self: RunnerService, player: Player)
	for _plotId, state in self.plots do
		if state.player ~= player then
			continue
		end
		state.startClock = workspace:GetServerTimeNow()
		self:_broadcastPlot(state)
	end
end

function RunnerService._broadcastPlot(self: RunnerService, state: PlotState, clearGateAwards: boolean?)
	if state.mergeEffectActive then
		return
	end

	-- roster changed -> some runners are gone; their award history is stale
	if clearGateAwards ~= false then
		table.clear(state.gateAwards)
		self:_anchorLapClocks(state)
	end

	local snapshot = self:_snapshot(state)
	self.networker:fireAll(
		"setRunners",
		snapshot.plotId,
		snapshot.owner,
		snapshot.runners,
		snapshot.startClock,
		snapshot.gateCount,
		snapshot.runnerSpeedLevel,
		snapshot.carSpeedMultiplier,
		snapshot.routeId,
		snapshot.selectedTrail
	)
end

function RunnerService.beginMergeEffect(self: RunnerService, plotId: number)
	local state = self.plots[plotId]
	if not state then
		return
	end

	state.mergeEffectActive = true
	state.mergeEffectId += 1
end

function RunnerService.playMergeEffect(self: RunnerService, plotId: number, operations: { RunnerServiceTypes.MergeOperation })
	local state = self.plots[plotId]
	if not state or #operations == 0 then
		return
	end

	if not state.mergeEffectActive then
		self:beginMergeEffect(plotId)
	end

	local effectId = state.mergeEffectId
	self.networker:fireAll("playMergeEffect", plotId, operations)

	task.delay(getMergeEffectDuration(operations), function()
		if self.plots[plotId] ~= state or state.mergeEffectId ~= effectId then
			return
		end

		state.mergeEffectActive = false
		self:_broadcastPlot(state)
	end)
end

-- Late-join sync: client fetches every known plot once on startup.
function RunnerService.requestState(self: RunnerService, _player: Player): { RunnerServiceTypes.RunnerPlotSnapshot }
	local snapshots: { RunnerServiceTypes.RunnerPlotSnapshot } = {}
	for _, state in self.plots do
		snapshots[#snapshots + 1] = self:_snapshot(state)
	end

	return snapshots
end

function RunnerService.reportLap(self: RunnerService, player: Player, plotId: number, runnerId: number)
	if typeof(plotId) ~= "number" or typeof(runnerId) ~= "number" or runnerId % 1 ~= 0 then
		return
	end

	local state = self.plots[plotId]
	if not state or state.player ~= player then
		return
	end

	-- roster is mid-rewrite; ids are meaningless until the next broadcast
	if state.mergeEffectActive then
		return
	end

	local profile = ProfileServiceServer.getProfile(player)
	local entries = RunnerUtils.sanitizeRunners(profile:getRunners())
	local entry = RunnerUtils.findRunner(entries, runnerId)
	if not entry then
		return
	end

	local timing = self:_getRunnerTiming(state, entry, profile:getUpgradeLevel("runnerSpeed"))
	if not timing or timing.travelTime <= 0 then
		return
	end

	local now = workspace:GetServerTimeNow()
	local lapClock = state.lapClocks[runnerId]
	if not lapClock then
		-- first report for this runner: anchor now, credit from here on
		state.lapClocks[runnerId] = now
		return
	end

	local lapsCompleted = math.floor((now - lapClock) / timing.travelTime)
	if lapsCompleted <= 0 then
		return
	end

	-- advance by whole laps only, so the leftover fraction carries over
	state.lapClocks[runnerId] = lapClock + lapsCompleted * timing.travelTime

	self:_spendLaps(player, lapsCompleted)
end

-- Pools laps from every runner on the plot and spends them against
-- lapsLeftToAcquire, awarding lucky blocks (possibly several in one go
-- if a client was AFK and reports a big lap batch at once).
function RunnerService._spendLaps(_self: RunnerService, player: Player, lapsGained: number)
	local remaining = DataService:get(player, { "lapsLeftToAcquire" }) - lapsGained

	DataService:set(player, { "lapsLeftToAcquire" }, math.max(0, remaining))
end

-- Authoritative gate validation. Recomputes the runner's deterministic
-- position and only pays if that gate really was crossed just now, at most
-- once per lap. Exploiters cannot exceed the legitimate income rate.
function RunnerService.reportGate(self: RunnerService, player: Player, plotId: number, runnerId: number, gateId: number)
	if typeof(plotId) ~= "number" or typeof(runnerId) ~= "number" or typeof(gateId) ~= "number" then
		return
	end

	if runnerId % 1 ~= 0 or gateId % 1 ~= 0 then
		return
	end

	local state = self.plots[plotId]
	if not state or state.player ~= player then
		return
	end

	local profile = ProfileServiceServer.getProfile(player)
	local entries = RunnerUtils.sanitizeRunners(profile:getRunners())

	local gateCount = profile:getActiveGateCount()
	if gateId < 1 or gateId > gateCount then
		return
	end

	-- Addressing by id means a report that arrives during a merge can only
	-- ever credit the car it belongs to, or nothing at all.
	local entry = RunnerUtils.findRunner(entries, runnerId)
	if not entry then
		return
	end

	local timing = self:_getRunnerTiming(state, entry, profile:getUpgradeLevel("runnerSpeed"))
	if not timing then
		return
	end

	local path = timing.path
	local gateDistance = path.gateDistances[gateId]
	if not gateDistance then
		return
	end

	local now = workspace:GetServerTimeNow()
	local progress = ((now - state.startClock) / timing.travelTime + timing.phase) % 1
	local distance = progress * path.length

	-- distance travelled since passing the gate must be small (just crossed)
	local delta = (distance - gateDistance) % path.length
	if delta > timing.speed * GATE_TOLERANCE_SECONDS then
		return
	end

	local awardKey = `{runnerId}_{gateId}`
	local lastAward = state.gateAwards[awardKey]
	if lastAward and now - lastAward < timing.travelTime * LAP_COOLDOWN_RATIO then
		return
	end
	state.gateAwards[awardKey] = now

	local income = RunnerUtils.getRunnerIncomePerLap(entry.level)
	local cashBonusLevel = profile:getUpgradeLevel("cashBonus")
	local route = profile:getRoute()
	local vipMultiplier = if state.vipOwned then 1.5 else 1
	local doubleCashMultiplier = if state.doubleCashOwned then 2 else 1
	income = math.max(
		1,
		math.round(
			income
				* RunnerUtils.getCashBonusMultiplier(cashBonusLevel)
				* FriendServiceServer:getFriendMultiplier(player)
				* DataService:get(player, { "cashMultiplier" })
				* DataService:get(player, { "customMultiplier" })
				* vipMultiplier
				* doubleCashMultiplier
				* state.trailMultiplier
				* RouteServiceUtils[route].cashMultiplier
		)
	)

	profile:giveCash(income)
end

type RunnerTiming = {
	path: PathData.Path,
	speed: number,
	travelTime: number,
	phase: number,
}

type PlotState = {
	plotId: number,
	player: Player,
	startClock: number,
	gateAwards: { [string]: number },
	lapClocks: { [number]: number },
	janitor: Janitor.Janitor,
	broadcastScheduled: boolean,
	mergeEffectActive: boolean,
	mergeEffectId: number,
	vipOwned: boolean,
	doubleCashOwned: boolean,
	doubleSpeedOwned: boolean,
	selectedTrail: number?,
	trailMultiplier: number,
	clearGateAwardsOnBroadcast: boolean,
}

type RunnerService = typeof(RunnerService) & {
	networker: Networker.Server,
	plots: { [number]: PlotState },
}

return RunnerService :: RunnerService
