--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local Charm = require(ReplicatedStorage.Packages.Charm)
local LeaderboardServiceUtils = require(script.Parent.LeaderboardServiceUtils)
local LeaderboardSlice = require(script.Parent.LeaderboardSlice)

type LeaderboardData = LeaderboardServiceUtils.LeaderboardData
type LeaderboardEntry = LeaderboardServiceUtils.LeaderboardEntry
type LeaderboardSliceId = LeaderboardSlice.LeaderboardSliceId

local leaderboardFolder = workspace:WaitForChild("_LEADERBOARDS")
local leaderboardModels: { [LeaderboardSliceId]: Instance } = {
	rebirthsLeaderboard = leaderboardFolder:WaitForChild("topRebirth"),
	cashLeaderboard = leaderboardFolder:WaitForChild("topCash"),
	playtimeLeaderboard = leaderboardFolder:WaitForChild("topPlaytime"),
}
local leaderboardEntrySample = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("leaderboardEntry")

local activeSubscriptions: { [LeaderboardSliceId]: (() -> ())? } = {}
local renderedEntries: { [LeaderboardSliceId]: { Instance } } = {}

local function clearRenderedEntries(sliceId: LeaderboardSliceId)
	local entries = renderedEntries[sliceId]
	if not entries then
		return
	end

	for _, entry in entries do
		entry:Destroy()
	end

	table.clear(entries)
end

local function renderLeaderboardEntry(playerDirectory: Instance, index: number, entryData: LeaderboardEntry)
	local entry = leaderboardEntrySample:Clone()
	entry.Name = `{index}`
	entry.Parent = playerDirectory

	entry.Headshot.Image = entryData.profileImageId
	entry.Rank.Text = `#{index}`
	entry.Username.Text = entryData.username
	entry.Value.Text = Abbreviate(entryData.value)

	entry.Visible = true
	entry.LayoutOrder = index

	return entry
end

local function renderLeaderboard(sliceId: LeaderboardSliceId, playerDirectory: Instance, leaderboardData: LeaderboardData)
	clearRenderedEntries(sliceId)

	local entries = renderedEntries[sliceId]
	if not entries then
		entries = {}
		renderedEntries[sliceId] = entries
	end

	for index, entryData in ipairs(leaderboardData) do
		local entry = renderLeaderboardEntry(playerDirectory, index, entryData)
		entries[#entries + 1] = entry
	end
end

local LeaderboardUI = {}

function LeaderboardUI.setupLeaderboard(sliceId: LeaderboardSliceId, leaderboardModel: Instance)
	local playerDirectory = leaderboardModel:WaitForChild("Part"):WaitForChild("SurfaceGui"):WaitForChild("players")
	local sliceAtom: Charm.Atom<LeaderboardData> = LeaderboardSlice.states[sliceId]

	if activeSubscriptions[sliceId] then
		activeSubscriptions[sliceId]()
		activeSubscriptions[sliceId] = nil
	end

	renderLeaderboard(sliceId, playerDirectory, sliceAtom())

	activeSubscriptions[sliceId] = Charm.subscribe(sliceAtom :: () -> LeaderboardData, function(newLeaderboardData)
		renderLeaderboard(sliceId, playerDirectory, newLeaderboardData)
	end)
end

function LeaderboardUI.init()
	LeaderboardUI.setupLeaderboard("rebirthsLeaderboard", leaderboardModels.rebirthsLeaderboard)
	LeaderboardUI.setupLeaderboard("cashLeaderboard", leaderboardModels.cashLeaderboard)
	LeaderboardUI.setupLeaderboard("playtimeLeaderboard", leaderboardModels.playtimeLeaderboard)
end

return LeaderboardUI
