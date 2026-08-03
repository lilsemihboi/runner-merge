local OfflineEarnings = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local MonetizationServiceServer = require(ServerScriptService.Services.MonetizationService.MonetizationServiceServer)
local Networker = require(ReplicatedStorage.Packages.Networker)
local OfflineEarningsServiceUtils = require(ReplicatedStorage.Shared.Services.OfflineEarningsService.OfflineEarningsServiceUtils)
local PathData = require(ReplicatedStorage.Shared.Classes.Runner.PathData)
local PlotServiceServer = require(ServerScriptService.Services.PlotService.PlotServiceServer)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)
local Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)

local OFFLINE_EARNINGS_MULTIPLIER = 0.7

function OfflineEarnings.init(self: OfflineEarnings)
	self.networker = Networker.server.new("OfflineEarnings", self, {
		self.requestBegin,
		self.requestClaim,
	})

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_create(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(function()
			self:_create(player)
		end)
	end)
end

function OfflineEarnings._create(self: OfflineEarnings, player: Player)
	DataService:waitForData(player)

	if player.Parent ~= Players then
		return
	end

	local lastLogoutTime = DataService:get(player, { "stats", "lastLogoutTime" })
	local offlineElapsed = if typeof(lastLogoutTime) == "number" then os.time() - lastLogoutTime else 0
	if OfflineEarningsServiceUtils.getEligibleOfflineSeconds(offlineElapsed) <= 0 then
		return
	end

	-- PlotService waits for ProfileService while creating the player's plot.  Do this
	-- work here, after data initialization, so ProfileService does not require us.
	while player.Parent == Players and not PlotServiceServer:getPlot(player) do
		task.wait()
	end

	if player.Parent ~= Players then
		return
	end

	local earnings = self:calculateOfflineEarnings(player, offlineElapsed)
	if earnings <= 0 then
		return
	end

	-- This product can be bought once for each newly-created offline reward.
	DataService:set(player, "offlineEarningsPaid", false)
	DataService:set(player, "offlineEarningsDoubled", false)
	DataService:set(player, "offlineEarnings", earnings)
end

local function getActiveGateDistances(path: PathData.Path, gateCount: number): { number }
	local gateDistances = {}
	for gateId = 1, math.max(0, math.floor(gateCount)) do
		local gateDistance = path.gateDistances[gateId]
		if gateDistance then
			gateDistances[#gateDistances + 1] = gateDistance
		end
	end

	table.sort(gateDistances)
	return gateDistances
end

local function countGateCrossings(gateDistances: { number }, pathLength: number, startDistance: number, distanceTravelled: number): number
	if pathLength <= 0 or distanceTravelled <= 0 or #gateDistances == 0 then
		return 0
	end

	local completedLaps = math.floor(distanceTravelled / pathLength)
	local crossings = completedLaps * #gateDistances
	local remainingDistance = distanceTravelled % pathLength
	local currentDistance = startDistance % pathLength

	for _, gateDistance in gateDistances do
		local distanceToGate = (gateDistance - currentDistance) % pathLength
		if distanceToGate > 0 and distanceToGate <= remainingDistance then
			crossings += 1
		end
	end

	return crossings
end

function OfflineEarnings.calculateOfflineEarnings(_self: OfflineEarnings, player: Player, timeElapsed: number?): number
	local eligibleOfflineSeconds = OfflineEarningsServiceUtils.getEligibleOfflineSeconds(timeElapsed)
	if eligibleOfflineSeconds <= 0 then
		return 0
	end

	local plot = PlotServiceServer:getPlot(player)
	if not plot then
		return 0
	end

	local profile = ProfileServiceServer.getProfile(player)
	local selectedTrail = profile:getSelectedTrail()
	local trailInfo = if selectedTrail then Trails[selectedTrail] else nil
	local trailMultiplier = if trailInfo then trailInfo.trailMultiplier else 1

	local path = PathData.get(plot.plotId, 1)
	if not path or path.length <= 0 then
		return 0
	end

	local levels = RunnerUtils.sanitizeLevels(profile:getRunners())
	local gateDistances = getActiveGateDistances(path, profile:getActiveGateCount())
	if #levels == 0 or #gateDistances == 0 then
		return 0
	end

	local runnerSpeedLevel = profile:getUpgradeLevel("runnerSpeed")
	local cashBonusMultiplier = RunnerUtils.getCashBonusMultiplier(profile:getUpgradeLevel("cashBonus"))
	local rebirthCashMultiplier = DataService:get(player, { "cashMultiplier" })
	local customMultiplier = DataService:get(player, { "customMultiplier" }) -- starter pack
	local vipMultiplier = if MonetizationServiceServer:ownsGamepass(player, Products.vip) == true then 1.5 else 1
	local earnings = 0

	for index, runnerLevel in levels do
		local speed = RunnerUtils.getRunnerSpeed(runnerLevel, runnerSpeedLevel)
		local phase = (index - 1) / #levels
		local startDistance = phase * path.length
		local distanceTravelled = speed * eligibleOfflineSeconds
		local gateCrossings = countGateCrossings(gateDistances, path.length, startDistance, distanceTravelled)
		local incomePerGate = math.max(1, math.round(RunnerUtils.getRunnerIncomePerLap(runnerLevel) * cashBonusMultiplier))

		earnings += gateCrossings * incomePerGate
	end

	return math.floor(earnings * OFFLINE_EARNINGS_MULTIPLIER * rebirthCashMultiplier * customMultiplier * vipMultiplier * trailMultiplier)
end

function OfflineEarnings.requestBegin(_self: OfflineEarnings, player: Player)
	local profile = ProfileServiceServer.getProfile(player)
	local reward = DataService:get(player, "offlineEarnings")

	if typeof(reward) ~= "number" or reward <= 0 then
		return false, "NO_REWARD"
	end

	if DataService:get(player, "offlineEarningsPaid") ~= true then
		DataService:set(player, "offlineEarningsPaid", true)
		profile:giveCash(reward)
	end

	return true, "SUCCESS", reward
end

function OfflineEarnings.requestClaim(_self: OfflineEarnings, player: Player)
	local profile = ProfileServiceServer.getProfile(player)
	local reward = DataService:get(player, "offlineEarnings")

	if typeof(reward) ~= "number" or reward <= 0 then
		return false, "NO_REWARD"
	end

	if DataService:get(player, "offlineEarningsPaid") ~= true then
		DataService:set(player, "offlineEarningsPaid", true)
		profile:giveCash(reward)
	end

	DataService:set(player, "offlineEarnings", nil)
	DataService:set(player, "offlineEarningsPaid", nil)
	DataService:set(player, "offlineEarningsDoubled", nil)

	return true, "SUCCESS"
end

type OfflineEarnings = typeof(OfflineEarnings) & {
	networker: Networker.Server,
}

return OfflineEarnings :: OfflineEarnings
