local Plot = {}
Plot.__index = Plot

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local FormatNameWithIcons = require(ReplicatedStorage.Shared.Modules.Ui.FormatNameWithIcons)
local GateServer = require(ServerScriptService.Classes.Gate.GateServer)
local GetPlayerPortaitImage = require(ReplicatedStorage.Shared.Modules.Ui.GetPlayerPortaitImage)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotServiceTypes = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceTypes)
local ProfileServer = require(ServerScriptService.Classes.Profile.ProfileServer)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RouteServiceUtils = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceUtils)
local RunnerServiceServer = require(ServerScriptService.Services.RunnerService.RunnerServiceServer)
local RunnerServiceTypes = require(ReplicatedStorage.Shared.Services.RunnerService.RunnerServiceTypes)
local Runners = require(ReplicatedStorage.Shared.Modules.Items.Runners)
local UpgradeUtils = require(ReplicatedStorage.Shared.Modules.Items.UpgradeUtils)
local _DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)

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
	}, Plot) :: Plot

	local networker = Networker.server.new(`plot_{player.Name}`, self, {
		self.merge,
		self.upgrade,
		self.addRunner,
		self.teleportToBase,
		self.giveGroupReward,
	})
	self.networker = networker
	self.networker:addRecipient(player)

	self.profile = ProfileServiceServer.getProfile(player)

	local tempFolder = Instance.new("Folder")
	tempFolder.Name = "_TEMP"
	tempFolder.Parent = self.plotModel
	self.janitor:Add(tempFolder, "Destroy")

	self:onCharacterAdded()
	self:setupSign()
	self:buildRunway(self.profile:getRoute())
	self:_watchRunners()
	self:_watchRunnerSpawnLevel()
	self:_checkForGates()

	-- runner simulation is fully client-side; RunnerService only broadcasts
	-- the roster + start signal and validates gate income
	RunnerServiceServer:registerPlot(player, plotId)

	return self :: Plot
end

function Plot._checkForGates(self: Plot)
	local function buildGates(count: number)
		for gateId, gate in self.gates do
			if gateId > count then
				gate:destroy()
				self.gates[gateId] = nil
			end
		end

		for gateId = 1, count do
			if not self.gates[gateId] then
				self.gates[gateId] = GateServer.new(self.player, self.plotId, gateId)
			end
		end
	end

	buildGates(self.profile:getUpgradeLevel("gates"))

	self.janitor:Add(
		DataService:getChangedSignal(self.player, { "upgrades", "gates" }):Connect(function(newValue)
			if typeof(newValue) == "number" then
				buildGates(newValue)
			end
		end),
		"Disconnect"
	)
end

function Plot.rebuildAllGates(self: Plot, count: number)
	for gateId, gate in self.gates do
		gate:destroy()
		self.gates[gateId] = nil
	end

	for gateId = 1, count do
		if not self.gates[gateId] then
			self.gates[gateId] = GateServer.new(self.player, self.plotId, gateId)
		end
	end
end

function Plot.upgrade(self: Plot, player: Player, upgradeId: keyof<typeof(_DataTemplate.upgrades)>): string
	assert(player == self.player, "You dont own the base!")

	if upgradeId ~= "cashBonus" and upgradeId ~= "gates" and upgradeId ~= "runnerSpeed" then
		return "WRONG_UPGRADE_ID"
	end

	local nextUpgradeId: number = self.profile:getUpgradeLevel(upgradeId) + 1

	if upgradeId == "gates" then
		local selectedRoute = self.profile:getRoute()

		if nextUpgradeId > RouteServiceUtils[selectedRoute].gateCap then
			return "MAX_LEVEL"
		end
	end

	if upgradeId ~= "gates" and nextUpgradeId > UpgradeUtils.levelCaps[upgradeId]() then
		return "MAX_LEVEL"
	end

	local nextUpgradeCost = UpgradeUtils.calculateUpgradeCost(upgradeId, nextUpgradeId)

	if self.profile:getCash() < nextUpgradeCost then
		return "NOT_ENOUGH_CASH"
	end

	self.profile:giveCash(-nextUpgradeCost)
	self.profile:giveUpgrade(upgradeId)

	return "SUCCESS"
end

function Plot.buildRunway(self: Plot, routeId: number)
	-- Destroy the old runway model
	if self.runwayModel then
		self.runwayModel:Destroy()
		self.runwayModel = nil
	end

	-- Build new one
	local routeTemplate: Model = game.ReplicatedStorage.Assets.Runways:FindFirstChild(`Runway{routeId}`) :: Model
	if not routeTemplate then
		return
	end

	self.runwayModel = routeTemplate:Clone() :: Model
	if self.runwayModel then
		self.runwayModel.Name = "Runway"
		self.runwayModel.Parent = self.plotModel
		self.runwayModel:PivotTo(self.plotModel.RouteSpawn.WorldCFrame)
	end
end

function Plot.setupSign(self: Plot)
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerImage.Image = GetPlayerPortaitImage(self.player.UserId)
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerName.Text = FormatNameWithIcons(self.player) .. "'s Base"
end

function Plot.teleportToBase(self: Plot, player: Player)
	assert(player == self.player, "You dont own the base!")

	local character = self.player.Character or self.player.CharacterAdded:Wait()

	local humanoidRootPart: BasePart = character:WaitForChild("HumanoidRootPart") :: BasePart
	humanoidRootPart.CFrame = self.plotModel.Spawn.WorldCFrame
end

function Plot.onCharacterAdded(self: Plot)
	self:teleportToBase(self.player)

	self.janitor:Add(
		self.player.CharacterAdded:Connect(function()
			self:teleportToBase(self.player)
		end),
		"Disconnect"
	)
end

function Plot.getPlotData(self: Plot): PlotServiceTypes.PlotData
	return {
		player = self.player,
		plotId = self.plotId,
	}
end

function Plot.destroy(self: Plot)
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerImage.Image = ""
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerName.Text = "Empty"

	RunnerServiceServer:unregisterPlot(self.player)

	for gateId, gate in self.gates do
		gate:destroy()
		self.gates[gateId] = nil
	end

	self.janitor:Destroy()
	self.networker:destroy()
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
			if runnerLevel < minLevel then
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

			if nextRunner and nextRunner.level == currentRunner.level then
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
		janitor: Janitor.Janitor,
		networker: Networker.Server,
		profile: ProfileServer.Profile,
		gates: { [number]: GateServer.Gate },
		_isApplyingRunnerMerge: boolean,
	},
	Plot
))

return Plot
