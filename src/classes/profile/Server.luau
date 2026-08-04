--[[
	Profile Class Module
	=====================================
	Manages player profile data including cash, rebirths, runners, upgrades, and tutorial progress.
	Acts as a wrapper around the DataService to provide type-safe access to player data.
]]

local Profile = {}
Profile.__index = Profile

-- Service References
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)
local Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)
local _DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local DataService = require(ReplicatedStorage.Packages.DataService).server
local RouteServiceUtils = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceUtils)

function Profile._waitForData(self: Profile)
	DataService:waitForData(self.player)
end

--[=[
	Creates a new profile instance for a player.
	Initializes a new Profile object that serves as an interface to the player's persistent data.
	
	@param player Player -- The player to create a profile for
	@return Profile -- A new Profile instance bound to the specified player
]=]
function Profile.new(player: Player): Profile
	-- Create a new table with metatables to associate it with the Profile class
	local self: Profile = setmetatable({
		player = player, -- Store reference to the player
	}, Profile)

	self:_waitForData()

	return self
end

--[[
	GETTER METHODS
	=====================================
	Methods for retrieving player data without modification.
	All getters perform a read operation from the DataService.
]]

--[=[
	Retrieves the player's current cash amount.
	Accesses the top-level "cash" field from the player's data.
	
	@return number -- The player's current cash balance
]=]
function Profile.getCash(self: Profile): number
	return DataService:get(self.player, "cash")
end

--[=[
	Retrieves the player's total number of rebirths.
	Rebirths represent significant progression milestones in the game.
	
	@return number -- The number of times the player has rebirthed
]=]
function Profile.getRebirths(self: Profile): number
	return DataService:get(self.player, "rebirths")
end

--[=[
	Retrieves the list of runner IDs owned by the player.
	Runners are entities/characters that the player controls.
	
	@return { number? } -- Array of runner numbers (may contain nil values)
]=]
function Profile.getRunners(self: Profile): { number? }
	return DataService:get(self.player, "runners")
end

--[=[
	Retrieves the current upgrade level for a specific upgrade.
	Each upgrade can be leveled up independently.
	
	@param upgradeId string -- The identifier of the upgrade to retrieve
	        Must be a valid key in DataTemplate.upgrades
	@return number -- The current level/tier of the specified upgrade
]=]
function Profile.getUpgradeLevel(self: Profile, upgradeId: keyof<typeof(_DataTemplate.upgrades)>): number
	return DataService:get(self.player, { "upgrades", upgradeId })
end

--[=[
	Retrieves the player's current tutorial step.
	Used to track progression through the tutorial sequence.
	
	@return number -- The current step number in the tutorial
]=]
function Profile.getTutorialStep(self: Profile): number
	return DataService:get(self.player, { "tutorial", "step" })
end

--[=[
	Checks whether the player has completed the tutorial.
	
	@return boolean -- True if the player has finished the tutorial, false otherwise
]=]
function Profile.getIsTutorialFinished(self: Profile): boolean
	return DataService:get(self.player, { "tutorial", "finished" })
end

--[[
	MUTATOR METHODS
	=====================================
	Methods for modifying player data.
	All mutators perform an update operation through the DataService.
]]

--[=[
	Awards cash to the player.
	Adds the specified amount to the player's current cash balance.
	
	@param amount number -- The amount of cash to give (positive value)
	@return () -- No return value
]=]
function Profile.giveCash(self: Profile, amount: number): ()
	DataService:update(self.player, { "cash" }, function(currentAmt)
		return currentAmt + amount -- Add amount to existing cash
	end)

	if amount <= 0 then
		return
	end

	DataService:update(self.player, { "stats", "totalCashEarned" }, function(current)
		return current + amount
	end)
end

--[=[
	Awards spin to the player.
	Adds the specified amount to the player's current spins.
	
	@param amount number -- The amount of cash to give (positive value)
	@return () -- No return value
]=]
function Profile.addSpin(self: Profile, amount: number): ()
	DataService:update(self.player, { "spins" }, function(currentAmt)
		return currentAmt + amount -- Add amount to existing spins
	end)
end

--[=[
	Resets cash of player

	@return () -- No return value
]=]
function Profile.resetCash(self: Profile): ()
	DataService:set(self.player, { "cash" }, 0)
end

--[=[
	Resets upgrades of player

	@return () -- No return value
]=]
function Profile.resetUpgrades(self: Profile): ()
	DataService:set(self.player, { "upgrades", "cashBonus" }, 0)
	DataService:set(self.player, { "upgrades", "gates" }, 0)
	DataService:set(self.player, { "upgrades", "runnerSpeed" }, 0)
end

--[=[
	Awards a rebirth to the player.
	Increments the player's rebirth counter by 1.
	Typically called when a player completes specific progression goals.
	
	@return () -- No return value
]=]
function Profile.giveRebirth(self: Profile): ()
	DataService:update(self.player, { "rebirths" }, function(currentAmt)
		return currentAmt + 1 -- Increment rebirth count
	end)
end

--[=[
	Sets rebirth multiplier of player.

	@return () -- No return value
]=]
function Profile.setMultiplier(self: Profile, multiplier: number): ()
	DataService:set(self.player, { "cashMultiplier" }, multiplier)
end

function Profile.setRoute(self: Profile, routeId: number): ()
	DataService:set(self.player, { "selectedRoute" }, routeId)
	return
end

function Profile.getRoute(self: Profile)
	return DataService:get(self.player, { "selectedRoute" })
end

--[=[
	Adds custom multiplier.

	@return () -- No return value
]=]
function Profile.addCustomMultiplier(self: Profile, multiplier: number): ()
	DataService:update(self.player, { "customMultiplier" }, function(current)
		return current + multiplier
	end)
end

function Profile.setExtraGateCount(self: Profile, amount: number)
	DataService:set(self.player, { "extraGates" }, amount)
end

function Profile.getExtraGateCount(self: Profile)
	return DataService:get(self.player, { "extraGates" })
end

function Profile.getActiveGateCount(self: Profile, routeId: number?): number
	local route = RouteServiceUtils[routeId or self:getRoute()]
	if not route then
		return 0
	end

	local cashGateCount = math.clamp(self:getUpgradeLevel("gates"), 0, route.cashGateCap)
	local extraGateCount = if cashGateCount >= route.cashGateCap then math.clamp(self:getExtraGateCount(), 0, route.gateCap - route.cashGateCap) else 0

	return cashGateCount + extraGateCount
end

function Profile.getCrateInQueue(self: Profile)
	return DataService:get(self.player, { "luckyBlockInQueue" })
end

function Profile.getLapsLeftToAcquire(self: Profile)
	return DataService:get(self.player, { "lapsLeftToAcquire" })
end

function Profile.setCrateInQueue(self: Profile, crateId: number?): ()
	DataService:set(self.player, { "luckyBlockInQueue" }, crateId)
	if crateId == nil then
		return
	end

	local crateInfo = Blocks.getBlock(crateId)

	DataService:set(self.player, { "lapsLeftToAcquire" }, crateInfo.lapsRequirement)
	return
end

--[=[
	Gives runner spawn level.

	@return () -- No return value
]=]
function Profile.giveSpawnLevel(self: Profile): ()
	DataService:update(self.player, { "runnerSpawnLevel" }, function(currentAmt)
		return currentAmt + 1
	end)
end

--[=[
	Gives player trail to earn more money $$.

	@param trailId number
	@return () -- No return value
]=]
function Profile.giveTrail(self: Profile, trailId: number): ()
	if not Trails[trailId] then
		return
	end

	DataService:arrayInsert(self.player, "inventory", trailId)
end

function Profile.hasTrail(self: Profile, trailId: number): boolean
	return table.find(DataService:get(self.player, "inventory"), trailId) ~= nil
end

function Profile.selectTrail(self: Profile, trailId: number?): boolean
	if trailId == nil then
		DataService:set(self.player, { "selectedTrail" }, nil)
		return true
	end

	if not Trails[trailId] then
		return false
	end

	if not self:hasTrail(trailId) then
		return false
	end

	DataService:set(self.player, { "selectedTrail" }, trailId)
	return true
end

function Profile.getSelectedTrail(self: Profile): number?
	return DataService:get(self.player, { "selectedTrail" })
end

--[=[
	Adds a runner to the player's collection.
	Assigns a new runner ID to the player's runners array.
	
	@param runnerLevel number -- Runner Level
	@param amount number -- Amount of runners
	@return () -- No return value
]=]
function Profile.giveRunner(self: Profile, runnerLevel: number, amount: number?): ()
	if not amount then
		amount = 1
	end

	DataService:update(self.player, "runnerPurchases", function(current)
		return current + amount
	end)

	local hasObtained = DataService:get(self.player, { "index", tostring(runnerLevel) }) == true

	if not hasObtained then
		DataService:set(self.player, { "index", tostring(runnerLevel) }, true)
	end

	for _ = 1, amount :: number, 1 do
		DataService:arrayInsert(self.player, "runners", runnerLevel)
	end
end

--[=[
	Checks if player has runner in their index or not
	
	@param runnerLevel number -- Runner Level
	@return boolean
]=]
function Profile.hasUnlockedRunner(self: Profile, runnerLevel: number): boolean
	return DataService:get(self.player, { "index", tostring(runnerLevel) }) == true
end

--[=[
	Awards an upgrade level to the player.
	Increments the specified upgrade's level by 1.
	
	@param upgradeId string -- The identifier of the upgrade to level up
	        Must be a valid key in DataTemplate.upgrades
	@return () -- No return value
]=]
function Profile.giveUpgrade(self: Profile, upgradeId: keyof<typeof(_DataTemplate.upgrades)>): ()
	DataService:update(self.player, { "upgrades", upgradeId }, function(current)
		return current + 1 -- Increment upgrade level
	end)
end

--[=[
	Advances the player's tutorial step.
	Increments the tutorial step counter by 1, moving to the next tutorial objective.
	
	@return () -- No return value
]=]
function Profile.stepTutorial(self: Profile): ()
	DataService:update(self.player, { "tutorial", "step" }, function(current)
		return current + 1 -- Move to next tutorial step
	end)
end

--[=[
	Marks the tutorial as complete for the player.
	Sets the tutorial finished flag to true, indicating the player has completed all tutorial steps.
	
	@return () -- No return value
]=]
function Profile.finishTutorial(self: Profile): ()
	DataService:set(self.player, { "tutorial", "finished" }, true)
end

--[[
	TYPE DEFINITION
	=====================================
	Exports the Profile type for use in type annotations throughout the codebase.
]]

export type Profile = typeof(setmetatable(
	{} :: {
		player: Player, -- Reference to the Player instance
	},
	Profile
))

return Profile
