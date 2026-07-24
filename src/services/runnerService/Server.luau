--[[
	RunnerService (server)
	=====================================
	Zero per-frame server load: NO Heartbeat, NO physics, NO models.
	The server only:
		1. Broadcasts each plot's runner roster + startClock ("start" signal)
		   whenever the runners array / gates upgrade changes (debounced).
		2. Authoritatively validates client gate-crossing reports on demand,
		   by recomputing the runner's deterministic progress from the shared
		   clock, and pays incomePerLap per validated gate crossing.

	Determinism contract (must match RunnerClient/RunnerManager exactly):
		travelTime = path.length / max(1, getRunnerSpeed(level, runnerSpeedLevel))
		phase      = (index - 1) / #levels
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

-- a reported gate must have been passed within the last N seconds (covers ping + frame time)
local GATE_TOLERANCE_SECONDS = 2
-- same (runner, gate) pair can only be awarded once per ~lap
local LAP_COOLDOWN_RATIO = 0.85

function RunnerService.init(self: RunnerService)
	self.plots = {}
	self.networker = Networker.server.new("RunnerService", self, {
		self.reportGate,
		self.requestState,
	})
end

function RunnerService.registerPlot(self: RunnerService, player: Player, plotId: number)
	self:unregisterPlot(player)

	local state: PlotState = {
		plotId = plotId,
		player = player,
		startClock = workspace:GetServerTimeNow(),
		gateAwards = {},
		janitor = Janitor.new(),
		broadcastScheduled = false,
		vipOwned = false,
		doubleCashOwned = false,
		doubleSpeedOwned = false,
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
		DataService:getChangedSignal(player, { "upgrades", "runnerSpeed" }):Connect(function()
			self:_scheduleBroadcast(state)
		end),
		"Disconnect"
	)

	state.janitor:Add(
		DataService:getChangedSignal(player, { "upgrades", "cashBonus" }):Connect(function()
			self:_scheduleBroadcast(state)
		end),
		"Disconnect"
	)

	if MonetizationServiceServer:ownsGamepass(player, Products.vip) then
		state.vipOwned = true
	end

	if MonetizationServiceServer:ownsGamepass(player, Products.x2Speed) then
		state.doubleSpeedOwned = true
	end

	if MonetizationServiceServer:ownsGamepass(player, Products.x2Cash) then
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
			state.doubleCashOwned = true
		end
	end))

	state.janitor:Add(MonetizationServiceServer:getPassOwnshipChanged(player, Products.vip):Connect(function(owns)
		if owns then
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
		levels = RunnerUtils.sanitizeLevels(profile:getRunners()),
		startClock = state.startClock,
		gateCount = profile:getUpgradeLevel("gates"),
		runnerSpeedLevel = profile:getUpgradeLevel("runnerSpeed"),
		carSpeedMultiplier = state.doubleSpeedOwned and 2 or 1,
		upgrades = {
			gates = profile:getUpgradeLevel("gates"),
			runnerSpeed = profile:getUpgradeLevel("runnerSpeed"),
			cashBonus = profile:getUpgradeLevel("cashBonus"),
		},
	}
end

-- merge() rewrites the whole array (many remove/insert signals in one frame);
-- defer so a burst collapses into a single broadcast.
function RunnerService._scheduleBroadcast(self: RunnerService, state: PlotState)
	if state.broadcastScheduled then
		return
	end

	state.broadcastScheduled = true
	task.defer(function()
		state.broadcastScheduled = false
		if self.plots[state.plotId] ~= state then
			return
		end

		self:_broadcastPlot(state)
	end)
end

function RunnerService._broadcastPlot(self: RunnerService, state: PlotState)
	-- roster changed -> indices/phases are re-assigned; old award history is stale
	table.clear(state.gateAwards)

	local snapshot = self:_snapshot(state)
	self.networker:fireAll(
		"setRunners",
		snapshot.plotId,
		snapshot.owner,
		snapshot.levels,
		snapshot.startClock,
		snapshot.gateCount,
		snapshot.runnerSpeedLevel,
		snapshot.carSpeedMultiplier,
		snapshot.upgrades
	)
end

function RunnerService.playMergeEffect(self: RunnerService, plotId: number, operations: { RunnerServiceTypes.MergeOperation })
	if not self.plots[plotId] or #operations == 0 then
		return
	end

	self.networker:fireAll("playMergeEffect", plotId, operations)
end

-- Late-join sync: client fetches every known plot once on startup.
function RunnerService.requestState(self: RunnerService, _player: Player): { RunnerServiceTypes.RunnerPlotSnapshot }
	local snapshots: { RunnerServiceTypes.RunnerPlotSnapshot } = {}
	for _, state in self.plots do
		snapshots[#snapshots + 1] = self:_snapshot(state)
	end

	return snapshots
end

-- Authoritative gate validation. Recomputes the runner's deterministic
-- position and only pays if that gate really was crossed just now, at most
-- once per lap. Exploiters cannot exceed the legitimate income rate.
function RunnerService.reportGate(self: RunnerService, player: Player, plotId: number, runnerIndex: number, gateId: number)
	if typeof(plotId) ~= "number" or typeof(runnerIndex) ~= "number" or typeof(gateId) ~= "number" then
		return
	end

	if runnerIndex % 1 ~= 0 or gateId % 1 ~= 0 then
		return
	end

	local state = self.plots[plotId]
	if not state or state.player ~= player then
		return
	end

	local profile = ProfileServiceServer.getProfile(player)
	local levels = RunnerUtils.sanitizeLevels(profile:getRunners())
	local level = levels[runnerIndex]
	if not level then
		return
	end

	local gateCount = profile:getUpgradeLevel("gates")
	if gateId < 1 or gateId > gateCount then
		return
	end

	local laneCount = PathData.getLaneCount(plotId)
	local lane = RunnerUtils.getRunnerLane(plotId, runnerIndex, laneCount)
	local path = PathData.get(plotId, lane)

	if not path or path.length <= 0 then
		return
	end

	local gateDistance = path.gateDistances[gateId]
	if not gateDistance then
		return
	end

	local runnerSpeedLevel = profile:getUpgradeLevel("runnerSpeed")
	local speed = RunnerUtils.getRunnerSpeed(level, runnerSpeedLevel)
	local doubleSpeedMultiplier = state.doubleSpeedOwned and 2 or 1
	local actualSpeed = speed * doubleSpeedMultiplier
	local travelTime = path.length / math.max(1, actualSpeed)
	local phase = (runnerIndex - 1) / #levels
	local now = workspace:GetServerTimeNow()
	local progress = ((now - state.startClock) / travelTime + phase) % 1
	local distance = progress * path.length

	-- distance travelled since passing the gate must be small (just crossed)
	local delta = (distance - gateDistance) % path.length
	if delta > actualSpeed * GATE_TOLERANCE_SECONDS then
		return
	end

	local awardKey = `{runnerIndex}_{gateId}`
	local lastAward = state.gateAwards[awardKey]
	if lastAward and now - lastAward < travelTime * LAP_COOLDOWN_RATIO then
		return
	end
	state.gateAwards[awardKey] = now

	local income = RunnerUtils.getRunnerIncomePerLap(level)
	local cashBonusLevel = profile:getUpgradeLevel("cashBonus")
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
		)
	)

	profile:giveCash(income)
	self.networker:fireAll("showGateIncome", plotId, gateId, income)
end

type PlotState = {
	plotId: number,
	player: Player,
	startClock: number,
	gateAwards: { [string]: number },
	janitor: Janitor.Janitor,
	broadcastScheduled: boolean,
	vipOwned: boolean,
	doubleCashOwned: boolean,
	doubleSpeedOwned: boolean,
}

type RunnerService = typeof(RunnerService) & {
	networker: Networker.Server,
	plots: { [number]: PlotState },
}

return RunnerService :: RunnerService
