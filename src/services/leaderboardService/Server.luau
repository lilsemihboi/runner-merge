local LeaderboardService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local LeaderboardPairs = require(ReplicatedStorage.Shared.Modules.Utils.LeaderboardPairs)
local LeaderboardServiceUtils = require(ReplicatedStorage.Shared.Services.LeaderboardService.LeaderboardServiceUtils)
local Networker = require(ReplicatedStorage.Packages.Networker)

type LeaderboardEntry = LeaderboardServiceUtils.LeaderboardEntry
type LeaderboardData = LeaderboardServiceUtils.LeaderboardData

local PREFIX = RunService:IsStudio() and "__test__" or "__production__"
local LEADERBOARD_UPDATE_INTERVAL = 60
local PLAYTIME_UPDATE_INTERVAL = 10
local rebirthsOrderedDataStore = DataStoreService:GetOrderedDataStore(PREFIX .. "RebirthsLeaderboard")
local cashOrderedDataStore = DataStoreService:GetOrderedDataStore(PREFIX .. "CashLeaderboard")
local playtimeOrderedDataStore = DataStoreService:GetOrderedDataStore(PREFIX .. "PlaytimeLeaderboard")

local dataStores = {
	["cashLeaderboard"] = cashOrderedDataStore,
	["playtimeLeaderboard"] = playtimeOrderedDataStore,
	["rebirthsLeaderboard"] = rebirthsOrderedDataStore,
}
local usernameCache: { [number]: string } = {}
local sessionStartedAt: { [Player]: number } = {}

function LeaderboardService.init(self: LeaderboardService)
	self.cashLeaderboard = {}
	self.playtimeLeaderboard = {}
	self.rebirthsLeaderboard = {}
	self.networker = Networker.server.new("LeaderboardService", self, {
		self.getLeaderboards,
	})

	for _, player in Players:GetPlayers() do
		sessionStartedAt[player] = os.time()
	end
	Players.PlayerAdded:Connect(function(player)
		sessionStartedAt[player] = os.time()
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessionStartedAt[player] = nil
	end)

	task.spawn(function()
		task.wait(5)
		while true do
			self:updatePlaytimePlayers()
			task.wait(PLAYTIME_UPDATE_INTERVAL)
		end
	end)

	task.spawn(function()
		task.wait(5)
		while true do
			self:updateLeaderboards()
			task.wait(LEADERBOARD_UPDATE_INTERVAL)
		end
	end)
end

function LeaderboardService.updatePlayers(_self: LeaderboardService)
	for _, player in Players:GetPlayers() do
		if not DataService:hasProfile(player) then
			continue
		end

		local totalCashEarned = math.round(DataService:get(player, { "stats", "totalCashEarned" }))
		local totalRebirths = math.round(DataService:get(player, { "rebirths" }))

		local success, err = pcall(function()
			cashOrderedDataStore:SetAsync(tostring(player.UserId), totalCashEarned)
			rebirthsOrderedDataStore:SetAsync(tostring(player.UserId), totalRebirths)
		end)

		if not success then
			warn(err)
		end
	end
end

function LeaderboardService.updatePlaytimePlayers(_self: LeaderboardService)
	for _, player in Players:GetPlayers() do
		if not DataService:hasProfile(player) then
			continue
		end

		local savedPlaytime = math.round(DataService:get(player, { "stats", "timePlayed" }))
		local totalPlaytime = savedPlaytime + math.max(0, os.time() - (sessionStartedAt[player] or os.time()))
		local success, err = pcall(playtimeOrderedDataStore.SetAsync, playtimeOrderedDataStore, tostring(player.UserId), totalPlaytime)

		if not success then
			warn(err)
		end
	end
end

function LeaderboardService.updateLeaderboard(_self: LeaderboardService, dataStore: OrderedDataStore): LeaderboardData?
	local success, pages = pcall(function()
		return dataStore:GetSortedAsync(false, 100)
	end)

	assert(success, "GetSortedAsync failed")

	local leaderboardData: LeaderboardData = {}
	for userId: number?, value: number? in LeaderboardPairs(pages) do
		userId = tonumber(userId) :: number
		local username = usernameCache[userId] or "[Failed To Load]"
		local profileImage = ""
		pcall(function()
			if not usernameCache[userId] then
				username = Players:GetNameFromUserIdAsync(userId)
				usernameCache[userId] = username
			end
			profileImage = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)

		local entry: LeaderboardEntry = {
			userId = userId,
			username = username,
			profileImageId = profileImage,
			value = value :: number,
		}

		table.insert(leaderboardData, entry)
	end

	return leaderboardData
end

function LeaderboardService.getLeaderboards(self: LeaderboardService)
	return {
		cashLeaderboard = self.cashLeaderboard,
		playtimeLeaderboard = self.playtimeLeaderboard,
		rebirthsLeaderboard = self.rebirthsLeaderboard,
	}
end

function LeaderboardService.updateLeaderboards(self: LeaderboardService)
	self:updatePlayers()

	for key, dataStore in pairs(dataStores) do
		local leaderboardData = self:updateLeaderboard(dataStore :: OrderedDataStore)
		if leaderboardData then
			self[key] = leaderboardData
			self.networker:fireAll("leaderboardUpdated", key, leaderboardData)
		end
	end
end

type LeaderboardService = typeof(LeaderboardService) & {
	networker: Networker.Server,
	cashLeaderboard: LeaderboardData,
	playtimeLeaderboard: LeaderboardData,
	rebirthsLeaderboard: LeaderboardData,
}

return LeaderboardService :: LeaderboardService
