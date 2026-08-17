local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local LeaderboardServiceUtils = require(script.Parent.LeaderboardServiceUtils)
local atom = Charm.atom

type Atom<T> = Charm.Atom<T>
type LeaderboardData = LeaderboardServiceUtils.LeaderboardData
export type LeaderboardSliceId = "rebirthsLeaderboard" | "cashLeaderboard" | "playtimeLeaderboard"

local rebirthsLeaderboard: Atom<LeaderboardData> = atom({})
local cashLeaderboard: Atom<LeaderboardData> = atom({})
local playtimeLeaderboard: Atom<LeaderboardData> = atom({})

local actions = {}

local states: { [LeaderboardSliceId]: Atom<LeaderboardData> } = {
	rebirthsLeaderboard = rebirthsLeaderboard,
	cashLeaderboard = cashLeaderboard,
	playtimeLeaderboard = playtimeLeaderboard,
}

return {
	actions = actions,
	states = states,
}
