--!nonstrict

local LeaderboardService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardServiceUtils = require(script.Parent.LeaderboardServiceUtils)
local LeaderboardSlice = require(script.Parent.LeaderboardSlice)
local LeaderboardUI = require(script.Parent.LeaderboardUI)
local Networker = require(ReplicatedStorage.Packages.Networker)

type LeaderboardData = LeaderboardServiceUtils.LeaderboardData
type LeaderboardSliceId = LeaderboardSlice.LeaderboardSliceId

function LeaderboardService.init(self: LeaderboardService)
	self.networker = Networker.client.new("LeaderboardService", self)

	task.spawn(function()
		local leaderboards: { [LeaderboardSliceId]: LeaderboardData } = self.networker:fetch("getLeaderboards")
		LeaderboardSlice.states.cashLeaderboard(leaderboards.cashLeaderboard)
		LeaderboardSlice.states.playtimeLeaderboard(leaderboards.playtimeLeaderboard)
		LeaderboardSlice.states.rebirthsLeaderboard(leaderboards.rebirthsLeaderboard)
	end)
	LeaderboardUI:init()
end

function LeaderboardService.leaderboardUpdated(_self: LeaderboardService, key: LeaderboardSliceId, leaderboardData: LeaderboardData)
	LeaderboardSlice.states[key](leaderboardData)
end

type LeaderboardService = typeof(LeaderboardService) & {
	networker: Networker.Client,
}

return LeaderboardService :: LeaderboardService
