local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local LeaderboardServiceUtils = require(script.Parent.LeaderboardServiceUtils)
local atom = Charm.atom

type Atom<T> = Charm.Atom<T>
type LeaderboardData = LeaderboardServiceUtils.LeaderboardData

local rebirthsLeaderboard: Atom<LeaderboardData> = atom({})
local cashLeaderboard: Atom<LeaderboardData> = atom({})

local actions = {}

return {
	actions = actions,
	states = {
		rebirthsLeaderboard = rebirthsLeaderboard,
		cashLeaderboard = cashLeaderboard,
	},
}
