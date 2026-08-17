local Plot = {}
Plot.__index = Plot

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local AnalyticsServiceServer = require(ServerScriptService.Services.AnalyticsService.AnalyticsServiceServer)
local ExclusiveCars = require(ReplicatedStorage.Shared.Modules.Items.ExclusiveCars)
local FormatNameWithIcons = require(ReplicatedStorage.Shared.Modules.Ui.FormatNameWithIcons)
local GateServer = require(ServerScriptService.Classes.Gate.GateServer)
local GetPlayerPortaitImage = require(ReplicatedStorage.Shared.Modules.Ui.GetPlayerPortaitImage)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Markers = require(ReplicatedStorage.Shared.Services.AnalyticsService.Markers)
local MonetizationServiceServer = require(ServerScriptService.Services.MonetizationService.MonetizationServiceServer)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotServiceTypes = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceTypes)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local ProfileServer = require(ServerScriptService.Classes.Profile.ProfileServer)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RouteServiceUtils = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceUtils)
local RunnerServiceServer = require(ServerScriptService.Services.RunnerService.RunnerServiceServer)

local RunnerServiceTypes = require(ReplicatedStorage.Shared.Services.RunnerService.RunnerServiceTypes)
local Runners = require(ReplicatedStorage.Shared.Modules.Items.Runners)
local UpgradeUtils = require(ReplicatedStorage.Shared.Modules.Items.UpgradeUtils)
local _DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)

local CRATE_SCALE = 0.649

function Plot.new(player: Player, plotId: number): Plot
	local plot = workspace._PLOTS:FindFirstChild(tostring(plotId))
	assert(plot and plot:IsA("Model"), "Plot Not Found!!")
	plot = plot :: Model

	local self: Plot = setmetatable({
		player = player,
		plotId = plotId,
		plotModel = plot,
		janitor = Janitor.new(),
		gates = {},
		_isApplyingRunnerMerge = false,
		_isDestroyed = false,
	}, Plot) :: Plot

	local success, problem = xpcall(function()
		self.networker = Networker.server.new(`plot_{player.UserId}`, self, {
			self.merge,
			self.upgrade,
			self.addRunner,
			self.teleportToBase,
			self.giveGroupReward,
			self.upgradeGatesWithPass,
		})
		self.networker:addRecipient(player)

		self.profile = ProfileServiceServer.getProfile(player)
		assert(player.Parent == Players, "Player left while their plot was being created")
		self:_setupStreaming()

		local tempFolder = Instance.new("Folder")
		tempFolder.Name = "_TEMP"
		tempFolder.Parent = self.plotModel
		self.janitor:Add(tempFolder, "Destroy")

		self:onCharacterAdded()
		self:setupSign()
		self:buildRunway(self.profile:getRoute())
		self:_watchCrate()
		self:_watchRunners()
		self:_watchRunnerSpawnLevel()
		self:_checkForGates()

		-- runner simulation is fully client-side; RunnerService only broadcasts
		-- the roster + start signal and validates gate income
		RunnerServiceServer:registerPlot(player, plotId)
	end, debug.traceback)

	if not success then
		self:destroy()
		error(problem, 0)
	end

	return self :: Plot
end

function Plot._setStreamingModel(self: Plot, instance: Instance)
	if not instance:IsA("Model") or self.player.Parent ~= Players then
		return
	end

	instance.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	local success, problem = pcall(instance.AddPersistentPlayer, instance, self.player)
	if not success and self.player.Parent == Players then
		warn(`[Plot] Failed to make {instance:GetFullName()} persistent for {self.player.Name}: {problem}`)
	end
end

function Plot._setupStreaming(self: Plot)
	self:_setStreamingModel(self.plotModel)

	for _, descendant in self.plotModel:GetDescendants() do
		self:_setStreamingModel(descendant)
	end

	self.janitor:Add(
		self.plotModel.DescendantAdded:Connect(function(descendant)
			self:_setStreamingModel(descendant)
		end),
		"Disconnect"
	)
end

function Plot._removePersistentPlayer(self: Plot)
	if self.player.Parent ~= Players then
		return
	end

	pcall(self.plotModel.RemovePersistentPlayer, self.plotModel, self.player)

	for _, descendant in self.plotModel:GetDescendants() do
		if descendant:IsA("Model") and descendant.ModelStreamingMode == Enum.ModelStreamingMode.PersistentPerPlayer then
			pcall(descendant.RemovePersistentPlayer, descendant, self.player)
		end
	end
end

function Plot._checkForGates(self: Plot)
	local function buildGates(count: number)
		for gateId, gate in self.gates do
			if gateId > count then
				gate:destroy()
				self.gates[gateId] = nil
			end
		end

		local selectedRouteId = self.profile:getRoute()
		local cashGateCap = RouteServiceUtils[selectedRouteId].cashGateCap

		for gateId = 1, count do
			if not self.gates[gateId] then
				local isExclusive = gateId > cashGateCap
				self.gates[gateId] = GateServer.new(self.player, self.plotId, gateId, isExclusive)
			end
		end
	end

	buildGates(self.profile:getActiveGateCount())

	self.janitor:Add(
		DataService:getChangedSignal(self.player, { "upgrades", "gates" }):Connect(function()
			buildGates(self.profile:getActiveGateCount())
		end),
		"Disconnect"
	)

	self.janitor:Add(
		DataService:getChangedSignal(self.player, { "extraGates" }):Connect(function()
			buildGates(self.profile:getActiveGateCount())
		end),
		"Disconnect"
	)
end

function Plot.rebuildAllGates(self: Plot)
	for gateId, gate in self.gates do
		gate:destroy()
		self.gates[gateId] = nil
	end

	local selectedRouteId = self.profile:getRoute()
	local cashGateCap = RouteServiceUtils[selectedRouteId].cashGateCap

	for gateId = 1, self.profile:getActiveGateCount() do
		if not self.gates[gateId] then
			local isExclusive = gateId > cashGateCap
			self.gates[gateId] = GateServer.new(self.player, self.plotId, gateId, isExclusive)
		end
	end
end

function Plot.upgradeGatesWithPass(self: Plot, player: Player)
	assert(player == self.player, "You dont own the base!")

	if not MonetizationServiceServer:ownsGamepass(self.player, Products.vip) then
		return false, "NO_VIP"
	end

	local currentSelectedRoute = self.profile:getRoute()
	local route = RouteServiceUtils[currentSelectedRoute]

	if self.profile:getUpgradeLevel("gates") < route.cashGateCap then
		return false, "BUY_GATES_FIRST"
	end

	local extraGateCount = self.profile:getExtraGateCount()

	if extraGateCount >= route.gateCap - route.cashGateCap then
		return false, "ALREADY_BOUGHT_EXTRAS"
	end

	self.profile:setExtraGateCount(extraGateCount + 1)
	return true, "SUCCESS"
end

function Plot.upgrade(self: Plot, player: Player, upgradeId: keyof<typeof(_DataTemplate.upgrades)>): string
	assert(player == self.player, "You dont own the base!")

	if upgradeId ~= "cashBonus" and upgradeId ~= "gates" and upgradeId ~= "runnerSpeed" then
		return "WRONG_UPGRADE_ID"
	end

	local nextUpgradeId: number = self.profile:getUpgradeLevel(upgradeId) + 1

	if upgradeId == "gates" then
		local selectedRoute = self.profile:getRoute()

		if nextUpgradeId > RouteServiceUtils[selectedRoute].cashGateCap then
			return "MAX_LEVEL"
		end
	end

	if upgradeId ~= "gates" and nextUpgradeId > UpgradeUtils.levelCaps[upgradeId]() then
		return "MAX_LEVEL"
	end

	local nextUpgradeCost = UpgradeUtils.calculateUpgradeCost(upgradeId, nextUpgradeId, self.profile:getRebirths())

	if self.profile:getCash() < nextUpgradeCost then
		return "NOT_ENOUGH_CASH"
	end

	self.profile:giveCash(-nextUpgradeCost)
	self.profile:giveUpgrade(upgradeId)

	return "SUCCESS"
end

function Plot.buildRunway(self: Plot, routeId: number)
	-- Destroy the old runway model
	self.janitor:Remove("runway")
	self.runwayModel = nil

	-- Build new one
	local routeTemplate = ReplicatedStorage.Assets.Runways:FindFirstChild(`Runway{routeId}`)
	if not routeTemplate or not routeTemplate:IsA("Model") then
		return
	end

	local runwayModel = routeTemplate:Clone()
	self.runwayModel = runwayModel
	-- Keyed so a route change replaces the previous runway, and so the plot's
	-- janitor destroys it when the player leaves.
	self.janitor:Add(runwayModel, "Destroy", "runway")

	runwayModel.Name = "Runway"
	runwayModel.Parent = self.plotModel
	runwayModel:PivotTo(self.plotModel.RouteSpawn.WorldCFrame)
end

--[=[
	Builds the crate sitting on the plot's LuckyBlock stand.

	The model is server-owned so every player can see what their neighbours are
	working toward. Its billboard and prompt stay client-driven, because both
	only mean anything to the crate's owner: PlotClient hides them on every
	stand except the local player's own.
]=]
function Plot.buildCrate(self: Plot, crateId: number?)
	-- Keyed so a new crate replaces the previous one, and so the plot's janitor
	-- destroys it when the player leaves.
	self.janitor:Remove("crate")
	self.crateModel = nil

	if crateId == nil then
		return
	end

	local crateTemplate = ReplicatedStorage.Assets.Blocks:FindFirstChild(tostring(crateId))
	if not crateTemplate or not crateTemplate:IsA("Model") then
		return
	end

	local crateModel = crateTemplate:Clone()
	self.crateModel = crateModel
	self.janitor:Add(crateModel, "Destroy", "crate")

	crateModel.Name = "Crate"
	crateModel:ScaleTo(CRATE_SCALE)
	crateModel.Parent = self.plotModel.LuckyBlock
	crateModel:PivotTo(self.plotModel.LuckyBlock.CrateSpawn.WorldCFrame)
end

function Plot._watchCrate(self: Plot)
	self:buildCrate(self.profile:getCrateInQueue())

	self.janitor:Add(
		DataService:getChangedSignal(self.player, { "luckyBlockInQueue" }):Connect(function(newValue)
			self:buildCrate(if typeof(newValue) == "number" then newValue else nil)
		end),
		"Disconnect"
	)
end

function Plot.setupSign(self: Plot)
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerImage.Image = GetPlayerPortaitImage(self.player.UserId)
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerName.Text = FormatNameWithIcons(self.player) .. "'s Base"
end

function Plot._teleportCharacterToBase(self: Plot, character: Model)
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
	if self._isDestroyed or character ~= self.player.Character or not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
		return
	end

	humanoidRootPart.CFrame = self.plotModel.Spawn.WorldCFrame
end

function Plot.teleportToBase(self: Plot, player: Player)
	assert(player == self.player, "You dont own the base!")

	local character = self.player.Character
	if character then
		task.spawn(self._teleportCharacterToBase, self, character)
	end
end

function Plot.onCharacterAdded(self: Plot)
	self.janitor:Add(
		self.player.CharacterAdded:Connect(function(character)
			task.spawn(self._teleportCharacterToBase, self, character)
		end),
		"Disconnect"
	)

	self:teleportToBase(self.player)
end

function Plot.getPlotData(self: Plot): PlotServiceTypes.PlotData
	return {
		player = self.player,
		plotId = self.plotId,
	}
end

function Plot.destroy(self: Plot)
	if self._isDestroyed then
		return
	end
	self._isDestroyed = true

	local sign = self.plotModel:FindFirstChild("Sign")
	if sign then
		local playerTable = sign:FindFirstChild("PlayerTable")
		local surfaceGui = playerTable and playerTable:FindFirstChild("SurfaceGui")
		local frame = surfaceGui and surfaceGui:FindFirstChild("Frame")
		local playerImage = frame and frame:FindFirstChild("PlayerImage")
		local playerName = frame and frame:FindFirstChild("PlayerName")
		if playerImage and playerImage:IsA("ImageLabel") then
			playerImage.Image = ""
		end
		if playerName and playerName:IsA("TextLabel") then
			playerName.Text = "Empty"
		end
	end

	self:_removePersistentPlayer()

	local runnerSuccess, runnerProblem = pcall(RunnerServiceServer.unregisterPlot, RunnerServiceServer, self.player)
	if not runnerSuccess then
		warn(`[Plot] Failed to unregister runners for {self.player.Name}: {runnerProblem}`)
	end

	for gateId, gate in self.gates do
		local gateSuccess, gateProblem = pcall(gate.destroy, gate)
		if not gateSuccess then
			warn(`[Plot] Failed to destroy gate {gateId} for {self.player.Name}: {gateProblem}`)
		end
		self.gates[gateId] = nil
	end

	local janitorSuccess, janitorProblem = pcall(self.janitor.Destroy, self.janitor)
	if not janitorSuccess then
		warn(`[Plot] Failed to clean plot {self.plotId} for {self.player.Name}: {janitorProblem}`)
	end

	if self.networker then
		local networkerSuccess, networkerProblem = pcall(self.networker.destroy, self.networker)
		if not networkerSuccess then
			warn(`[Plot] Failed to destroy plot networker for {self.player.Name}: {networkerProblem}`)
		end
	end
end

function Plot._watchRunnerSpawnLevel(self: Plot)
	self.janitor:Add(
		DataService:getChangedSignal(self.player, { "runnerSpawnLevel" }):Connect(function(newValue)
			if typeof(newValue) ~= "number" then
				return
			end

			self:_bumpLowLevelRunners(newValue)
		end),
		"Disconnect"
	)
end

function Plot.giveGroupReward(self: Plot, player: Player): (boolean, string?)
	assert(player == self.player, "You dont own the base!")

	local isGroupRewardClaimed = DataService:get(self.player, { "isGroupRewardClaimed" })
	if isGroupRewardClaimed then
		return false, "REWARD_ALREADY_CLAIMED"
	end

	local success, isInGroup = pcall(function()
		return player:IsInGroupAsync(113923204)
	end)

	if not success then
		return false, "ERROR"
	end

	if not isInGroup then
		return false, "NOT_IN_GROUP"
	end

	-- Set it as given
	DataService:set(self.player, { "isGroupRewardClaimed" }, true)

	-- Reward stuff after
	self.profile:addCustomMultiplier(0.05)
	self.profile:giveCash(15_000)
	self.profile:giveRunner(4)

	return true, "SUCCESS"
end

function Plot._bumpLowLevelRunners(self: Plot, minLevel: number)
	-- First, let existing duplicates merge naturally (e.g. two level-1s become a level-2)
	-- before we flatten anything up to minLevel.
	self:merge(self.player)

	local runnerLevels = self.profile:getRunners()
	local changedAny = false

	local newLevels: { number } = {}
	for _, runnerLevel in ipairs(runnerLevels) do
		if typeof(runnerLevel) == "number" then
			-- Exclusives sit in a reserved high id band, so they are already
			-- above any minLevel today. The guard keeps a future low-band
			-- exclusive from being silently flattened away on rebirth.
			if runnerLevel < minLevel and not ExclusiveCars.isExclusive(runnerLevel) then
				changedAny = true
				newLevels[#newLevels + 1] = minLevel
			else
				newLevels[#newLevels + 1] = runnerLevel
			end
		end
	end

	if not changedAny then
		return
	end

	self._isApplyingRunnerMerge = true

	for index = #runnerLevels, 1, -1 do
		DataService:arrayRemove(self.player, { "runners" }, index)
	end

	for index, runnerLevel in ipairs(newLevels) do
		DataService:arrayInsert(self.player, { "runners" }, runnerLevel, index)
	end

	self._isApplyingRunnerMerge = false

	-- Bumping several runners to the same minLevel can create new duplicates.
	self:merge(self.player)
end

type MergeCandidate = {
	level: number,
	source: RunnerServiceTypes.MergeSource,
}

function Plot.merge(self: Plot, player: Player)
	assert(player == self.player, "You dont own the base!")

	local runnerLevels = self.profile:getRunners()
	local sortedLevels: { MergeCandidate } = {}

	for _, runnerLevel in ipairs(runnerLevels) do
		if typeof(runnerLevel) == "number" then
			sortedLevels[#sortedLevels + 1] = {
				level = runnerLevel,
				source = {
					runnerIndex = #sortedLevels + 1,
				},
			}
		end
	end

	if #sortedLevels < 2 then
		return
	end

	table.sort(sortedLevels, function(left, right)
		return left.level < right.level
	end)

	local newlyUnlockedLevels: { number } = {}
	local mergeOperations: { RunnerServiceTypes.MergeOperation } = {}

	local mergedLevels: { MergeCandidate } = {}
	local changed = true
	while changed do
		changed = false
		local index = 1
		mergedLevels = {}

		while index <= #sortedLevels do
			local currentRunner = sortedLevels[index]
			local nextRunner = sortedLevels[index + 1]

			-- Exclusive cars are never mergeable, so they fall through to the
			-- carry-forward branch even when a player owns two of the same one.
			if nextRunner and nextRunner.level == currentRunner.level and not ExclusiveCars.isExclusive(currentRunner.level) then
				local newLevel = currentRunner.level + 1
				local operationId = #mergeOperations + 1
				mergedLevels[#mergedLevels + 1] = {
					level = newLevel,
					source = {
						resultId = operationId,
					},
				}
				newlyUnlockedLevels[#newlyUnlockedLevels + 1] = newLevel
				mergeOperations[#mergeOperations + 1] = {
					id = operationId,
					sourceLevel = currentRunner.level,
					resultLevel = newLevel,
					leftSource = currentRunner.source,
					rightSource = nextRunner.source,
				}
				index += 2
				changed = true
			else
				mergedLevels[#mergedLevels + 1] = currentRunner
				index += 1
			end
		end

		sortedLevels = mergedLevels
		table.sort(sortedLevels, function(left, right)
			return left.level < right.level
		end)
	end

	if #mergeOperations == 0 then
		return "NO_MATCHING_RUNNERS"
	end

	local mergedRunnerLevels = {}
	for _, runner in ipairs(sortedLevels) do
		mergedRunnerLevels[#mergedRunnerLevels + 1] = runner.level
	end

	RunnerServiceServer:beginMergeEffect(self.plotId)
	self._isApplyingRunnerMerge = true

	for index = #runnerLevels, 1, -1 do
		DataService:arrayRemove(self.player, { "runners" }, index)
	end

	for index, runnerLevel in ipairs(mergedRunnerLevels) do
		DataService:arrayInsert(self.player, { "runners" }, runnerLevel, index)
	end

	-- Register any newly-reached levels in the index
	for _, level in ipairs(newlyUnlockedLevels) do
		if not self.profile:hasUnlockedRunner(level) then
			DataService:set(self.player, { "index", tostring(level) }, true)
		end
	end

	self._isApplyingRunnerMerge = false
	RunnerServiceServer:playMergeEffect(self.plotId, mergeOperations)

	-- One marker per cascade rather than per pairing: auto-merge at 20 runners
	-- can chain dozens of operations from a single player action, and counting
	-- those individually would drown out the shape we actually care about.
	local highestResultLevel = 0
	for _, operation in mergeOperations do
		if operation.resultLevel > highestResultLevel then
			highestResultLevel = operation.resultLevel
		end
	end

	AnalyticsServiceServer:sendPlayerMarker(self.player, Markers.runnerMerged, {
		mergeCount = #mergeOperations,
		highestResultLevel = highestResultLevel,
		runnerCountBefore = #runnerLevels,
		runnerCountAfter = #mergedRunnerLevels,
	})

	return "SUCCESS"
end

function Plot.addRunner(self: Plot, player: Player, runnerAmount: number)
	if runnerAmount ~= 1 and runnerAmount ~= 5 and runnerAmount ~= 25 and runnerAmount ~= 50 then
		Players:BanAsync({
			UserIds = {
				player.UserId,
			},
			ApplyToUniverse = true,
			Duration = -1,
			DisplayReason = "Your account has been permanently suspended for exploiting or attempting to manipulate the game.",
			PrivateReason = `AUTO[Remote/Method]: Plot.addRunner is exploited; invalid runner amount {runnerAmount} expected 1,5,25 or 50`,
		})
	end
	assert(player == self.player, "You dont own the base!")

	local cost = Runners.calculateRunnerBatchPrice(DataService:get(self.player, "runnerPurchases"), runnerAmount)
	if self.profile:getCash() < cost then
		return "NOT_ENOUGH_CASH"
	end

	local runnerSpawnLevel = DataService:get(self.player, "runnerSpawnLevel")

	self.profile:giveCash(-cost)
	self.profile:giveRunner(runnerSpawnLevel, runnerAmount)

	return "SUCCESS"
end

-- Runner objects no longer exist on the server (simulation is client-side);
-- this only watches the data array to trigger the auto-merge at 20 runners.
function Plot._watchRunners(self: Plot)
	self.janitor:Add(
		DataService:getArrayInsertedSignal(self.player, { "runners" }):Connect(function()
			if self._isApplyingRunnerMerge then
				return
			end

			if #self.profile:getRunners() >= 20 then
				self:merge(self.player)
			end
		end),
		"Disconnect"
	)
end

export type Plot = typeof(setmetatable(
	{} :: {
		player: Player,
		plotId: number,
		plotModel: typeof(workspace._PLOTS["1"]),
		runwayModel: Model?,
		crateModel: Model?,
		janitor: Janitor.Janitor,
		networker: Networker.Server,
		profile: ProfileServer.Profile,
		gates: { [number]: GateServer.Gate },
		_isApplyingRunnerMerge: boolean,
		_isDestroyed: boolean,
	},
	Plot
))

return Plot
