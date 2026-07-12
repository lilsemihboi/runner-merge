local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local LeaderboardServiceUtils = require(script.Parent.LeaderboardServiceUtils)
local atom = Charm.atom

type Atom<T> = Charm.Atom<T>
type LeaderboardData = LeaderboardServiceUtils.LeaderboardData
export type LeaderboardSliceId = "rebirthsLeaderboard" | "cashLeaderboard"

local rebirthsLeaderboard: Atom<LeaderboardData> = atom({})
local cashLeaderboard: Atom<LeaderboardData> = atom({})

local actions = {}

local states: { [LeaderboardSliceId]: Atom<LeaderboardData> } = {
	rebirthsLeaderboard = rebirthsLeaderboard,
	cashLeaderboard = cashLeaderboard,
}

return {
	actions = actions,
	states = states,
}
