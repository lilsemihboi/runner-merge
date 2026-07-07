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
local RunnerServiceServer = require(ServerScriptService.Services.RunnerService.RunnerServiceServer)
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
	self:_watchRunners()
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

	RunnerServiceServer:unregisterPlot(self.player)

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

	local cost = Runners.calculateRunnerPrice(DataService:get(self.player, "runnerPurchases") + runnerAmount)
	if self.profile:getCash() < cost then
		return "CASH_NOT_ENOUGH"
	end

	self.profile:giveCash(-cost)
	self.profile:giveRunner(1, runnerAmount)

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
		janitor: Janitor.Janitor,
		networker: Networker.Server,
		profile: ProfileServer.Profile,
		gates: { [number]: GateServer.Gate },
		_isApplyingRunnerMerge: boolean,
	},
	Plot
))

return Plot
