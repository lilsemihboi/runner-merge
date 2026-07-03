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
local _DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local DataService = require(ReplicatedStorage.Packages.DataService).server

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

	DataService:update(self.player, { "stats", "totalCashEarned" }, function(current)
		return current + amount
	end)
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
	Adds a runner to the player's collection.
	Assigns a new runner ID to the player's runners array.
	
	@param runnerLevel number -- Runner Level
	@param amount number -- Amount of runners
	@return () -- No return value
]=]
function Profile.giveRunner(self: Profile, runnerLevel: number, amount: number?): ()
	if amount then
		for _ = 1, amount, 1 do
			DataService:arrayInsert(self.player, "runners", runnerLevel)
		end
		return
	end
	DataService:arrayInsert(self.player, "runners", runnerLevel)
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
