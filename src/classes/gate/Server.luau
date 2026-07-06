local Gate = {}
Gate.__index = Gate

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)

function Gate.new(player: Player): Gate
	local profile = ProfileServiceServer.getProfile(player)
	assert(profile, "No profile found")

	local previousGateCount = profile:getUpgradeLevel("gates")
	local newGateCount = previousGateCount + 1

	assert(newGateCount <= 10, "Gate count cant be bigger than 10")

	local self = setmetatable({
		gateId = newGateCount,
		janitor = Janitor.new(),
	}, Gate) :: Gate

	self:placeGate()

	return self
end

function Gate.placeGate(_self: Gate) end

export type Gate = typeof(setmetatable(
	{} :: {
		gateId: number,
		gateModel: Model?,
		janitor: Janitor.Janitor,
	},
	Gate
))

return Gate
