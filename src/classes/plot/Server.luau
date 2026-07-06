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
local RunnerServer = require(ServerScriptService.Classes.Runner.RunnerServer)
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
		runners = {},
		gates = {},
		_isApplyingRunnerMerge = false,
	}, Plot) :: Plot

	local networker = Networker.server.new(`plot_{player.Name}`, self, {
		self.merge,
		self.upgrade,
		self.addRunner,
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
	self:_createRunners()
	self:_checkForGates()

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

function Plot.upgrade(self: Plot, player: Player, upgradeId: keyof<typeof(_DataTemplate.upgrades)>): string
	assert(player == self.player, "You dont own the base!")

	if upgradeId ~= "cashBonus" and upgradeId ~= "gates" and upgradeId ~= "runnerSpeed" then
		return "WRONG_UPGRADE_ID"
	end

	local nextUpgradeId: number = self.profile:getUpgradeLevel(upgradeId) + 1

	if nextUpgradeId > UpgradeUtils.levelCaps[upgradeId] then
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

function Plot.setupSign(self: Plot)
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerImage.Image = GetPlayerPortaitImage(self.player.UserId)
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerName.Text = FormatNameWithIcons(self.player) .. "'s Base"
end

function Plot.onCharacterAdded(self: Plot)
	local function teleport()
		local character = self.player.Character or self.player.CharacterAdded:Wait()

		local humanoidRootPart: BasePart = character:WaitForChild("HumanoidRootPart") :: BasePart
		humanoidRootPart.CFrame = self.plotModel.Spawn.WorldCFrame
	end

	teleport()

	self.janitor:Add(self.player.CharacterAdded:Connect(teleport), "Disconnect")
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

	for gateId, gate in self.gates do
		gate:destroy()
		self.gates[gateId] = nil
	end

	self.janitor:Destroy()
	self.networker:destroy()
end

function Plot.merge(self: Plot, player: Player)
	assert(player == self.player, "You dont own the base!")

	local runnerLevels = self.profile:getRunners()
	local sortedLevels: { number } = {}

	for _, runnerLevel in ipairs(runnerLevels) do
		if typeof(runnerLevel) == "number" then
			sortedLevels[#sortedLevels + 1] = runnerLevel
		end
	end

	if #sortedLevels < 2 then
		return
	end

	table.sort(sortedLevels)

	local mergedLevels: { number } = {}
	local changed = true
	while changed do
		changed = false
		local index = 1
		mergedLevels = {}

		while index <= #sortedLevels do
			local currentLevel = sortedLevels[index]
			local nextLevel = sortedLevels[index + 1]

			if nextLevel == currentLevel then
				mergedLevels[#mergedLevels + 1] = currentLevel + 1
				index += 2
				changed = true
			else
				mergedLevels[#mergedLevels + 1] = currentLevel
				index += 1
			end
		end

		sortedLevels = mergedLevels
		table.sort(sortedLevels)
	end

	local mergedRunnerLevels = {}
	for _, runnerLevel in ipairs(sortedLevels) do
		mergedRunnerLevels[#mergedRunnerLevels + 1] = runnerLevel
	end

	self._isApplyingRunnerMerge = true

	for index = #runnerLevels, 1, -1 do
		DataService:arrayRemove(self.player, { "runners" }, index)
	end

	for index, runnerLevel in ipairs(mergedRunnerLevels) do
		DataService:arrayInsert(self.player, { "runners" }, runnerLevel, index)
	end

	for index = 1, math.max(#mergedRunnerLevels, #self.runners) do
		local existingRunner = self.runners[index]
		local newLevel = mergedRunnerLevels[index]

		if existingRunner and newLevel then
			existingRunner:updateLevel(newLevel)
		elseif newLevel then
			self.runners[index] = RunnerServer.new(newLevel, self.plotId)
		elseif existingRunner then
			existingRunner:destroy()
			self.runners[index] = nil
		end
	end

	self._isApplyingRunnerMerge = false
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
	--TODO: Calculate cost

	self.profile:giveRunner(1, runnerAmount)
end

function Plot._createRunners(self: Plot)
	for index, runnerLevel in self.profile:getRunners() do
		local newRunner = RunnerServer.new(runnerLevel, self.plotId)
		self.runners[index] = newRunner
	end

	DataService:getArrayInsertedSignal(self.player, { "runners" }):Connect(function(index, runnerLevel)
		if self._isApplyingRunnerMerge then
			return
		end

		local newRunner = RunnerServer.new(runnerLevel, self.plotId)
		self.runners[index] = newRunner

		if #self.profile:getRunners() >= 20 then
			self:merge(self.player)
		end
	end)

	DataService:getArrayRemovedSignal(self.player, { "runners" }):Connect(function(index)
		if self._isApplyingRunnerMerge then
			return
		end

		if self.runners[index] then
			self.runners[index]:destroy()
			self.runners[index] = nil
		end
	end)
end

export type Plot = typeof(setmetatable(
	{} :: {
		player: Player,
		plotId: number,
		plotModel: typeof(workspace._PLOTS["1"]),
		janitor: Janitor.Janitor,
		networker: Networker.Server,
		profile: ProfileServer.Profile,
		runners: { [number]: RunnerServer.Runner },
		gates: { [number]: GateServer.Gate },
		_isApplyingRunnerMerge: boolean,
	},
	Plot
))

return Plot
