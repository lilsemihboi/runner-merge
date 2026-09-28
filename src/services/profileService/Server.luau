--[=[
	Profile Service Module
	=====================================
	Manages player profile lifecycle and data initialization.
]=]

local ProfileService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local ProfileServer = require(ServerScriptService.Classes.Profile.ProfileServer)
local Signal = require(ReplicatedStorage.Packages.Signal)

local profiles: { [Player]: ProfileServer.Profile } = {} -- Maps players to their profile instances
local failedProfiles: { [Player]: boolean } = {}
local playersJoinedAt: { [Player]: number } = {} -- Tracks session start time for each player
local profileCreationSignal = Signal.new() -- Fired when a player's profile is created

--[=[
	Initializes the ProfileService.
	Creates profiles for any players already in the game and sets up connection events.
	
	@return () -- No return value
]=]
function ProfileService.init(self: ProfileService)
	-- Create profiles for players already in the server (e.g., during hot reload)
	for _, player in Players:GetPlayers() do
		self:_create(player)
	end

	-- Listen for new players joining
	Players.PlayerAdded:Connect(function(player: Player)
		self:_create(player)
	end)
end

function ProfileService.initLeaderstats(self: ProfileService, player: Player)
	DataService:waitForData(player)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = "$" .. Abbreviate(self.getProfile(player):getCash())
	cash.Parent = leaderstats

	local rebirths = Instance.new("StringValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = Abbreviate(self.getProfile(player):getRebirths())
	rebirths.Parent = leaderstats

	DataService:getChangedSignal(player, "cash"):Connect(function(current: number)
		cash.Value = "$" .. Abbreviate(current)
	end)

	DataService:getChangedSignal(player, "rebirths"):Connect(function(current: number)
		rebirths.Value = Abbreviate(current)
	end)

	leaderstats.Parent = player
end

--[=[
	Creates a new profile for a player and caches it.
	Called when a player joins the game or during service initialization.
	
	@param player Player -- The player to create a profile for
	@return () -- No return value
]=]
function ProfileService._create(self: ProfileService, player: Player)
	-- Guard against duplicate profile creation
	if profiles[player] then
		return
	end

	-- Instantiate a new profile for the player
	local profile = ProfileServer.new(player)
	if not profile then
		failedProfiles[player] = true
		profileCreationSignal:Fire(player)
		return
	end

	-- Cache the profile and record session start time
	profiles[player] = profile
	playersJoinedAt[player] = os.time()

	-- Fire signal to notify listeners that this player's profile is ready
	profileCreationSignal:Fire(player)
	self:initLeaderstats(player)
end

--[=[
	Retrieves a player's profile, waiting for it to be created if necessary.
	Uses signals to wait for profile initialization if not immediately available.
	
	@param player Player -- The player whose profile to retrieve
	@return ProfileServer.Profile -- The player's profile
]=]
function ProfileService.getProfile(player: Player): ProfileServer.Profile
	-- If profile already exists, return it immediately
	if profiles[player] then
		return profiles[player]
	end

	-- Wait for the profile to be created using the signal
	-- Keep waiting until the profile is created for this player
	while not profiles[player] and not failedProfiles[player] do
		local createdPlayer = profileCreationSignal:Wait()
		if createdPlayer == player then
			break
		end
	end

	return assert(profiles[player], `Profile was not created for {player.Name}`)
end

--[=[
	Converts saves from the pre-entry `runners` schema (one bare level per slot)
	to `{ id, level, phase }` entries.

	A car's identity and position used to be its array index, so this assigns
	exactly the values the old scheme would have computed - `id = index` and
	`phase = (index - 1) / count` - which keeps both the lane hash and the
	position identical the first time an old save loads. Nothing moves.

	Runs from `onPlayerInit`, before the data is replicated, so the client only
	ever sees the new shape.
]=]
local function migrateRunners(data: any)
	local runners = data.runners
	if type(runners) ~= "table" then
		data.runners = {}
		return
	end

	local legacyLevels: { number } = {}
	local highestId = if typeof(data.nextRunnerId) == "number" then data.nextRunnerId else 0

	for _, runner in ipairs(runners) do
		if typeof(runner) == "number" then
			legacyLevels[#legacyLevels + 1] = runner
		elseif typeof(runner) == "table" and typeof(runner.id) == "number" then
			highestId = math.max(highestId, runner.id)
		end
	end

	if #legacyLevels > 0 then
		local migrated: { any } = {}
		for index, runnerLevel in ipairs(legacyLevels) do
			migrated[index] = {
				id = index,
				level = runnerLevel,
				phase = (index - 1) / #legacyLevels,
			}
		end

		data.runners = migrated
		highestId = math.max(highestId, #migrated)
	end

	data.nextRunnerId = highestId
end

--[=[
	Called by DataService when a player's data is initialized.
	Reconciles player data with the default template to handle schema evolution.
	
	This ensures that:
	- New fields added to DataTemplate are populated in existing player data
	- Default values are applied for missing fields
	- Old/deprecated fields can be handled appropriately
	
	@param player Player -- The player whose data is being initialized
	@param data DataTemplate.DataSchema -- The player's loaded data
	@return () -- No return value
]=]
function DataService:onPlayerInit(_player: Player, data: DataTemplate.DataSchema)
	-- Recursively merge defaults from template into player data
	local function reconcileData(playerData: any, template: any)
		for key, defaultValue in pairs(template) do
			-- If field doesn't exist in player data, add it with default value
			if playerData[key] == nil then
				if typeof(defaultValue) == "table" then
					-- For nested objects, create a copy of the template
					playerData[key] = table.clone(defaultValue)
				else
					playerData[key] = defaultValue
				end
			elseif typeof(defaultValue) == "table" and typeof(playerData[key]) == "table" then
				-- Recursively reconcile nested tables
				reconcileData(playerData[key], defaultValue)
			end
		end
	end

	-- Reconcile player data with the template
	reconcileData(data, DataTemplate)

	-- Must run after reconcile so a fresh `nextRunnerId` already exists
	migrateRunners(data)
end

--[=[
	Player Removal Callback
	=====================================
	Called by DataService when a player is about to be removed from the server.
	Updates persistent player statistics before data is saved to storage.
]=]
DataService:addPlayerRemovingCallback(function(player: Player, data)
	data.stats.lastLogoutTime = os.time()
	data.offlineEarnings = nil
	data.offlineEarningsPaid = nil
	data.offlineEarningsDoubled = nil

	local sessionStart = playersJoinedAt[player]
	if sessionStart then
		local sessionDuration = os.time() - sessionStart
		data.stats.timePlayed = data.stats.timePlayed + sessionDuration
	end

	-- Clean up session tracking
	playersJoinedAt[player] = nil

	local profile = profiles[player]
	if not profile then
		failedProfiles[player] = nil
		return
	end

	-- Clear the player's profile from cache
	profiles[player] = nil
	failedProfiles[player] = nil
end)

type ProfileService = typeof(ProfileService)

return ProfileService :: ProfileService
