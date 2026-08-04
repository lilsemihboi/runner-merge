--!nonstrict

local BlockService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)
local Networker = require(ReplicatedStorage.Packages.Networker)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local Rarities = require(ReplicatedStorage.Shared.Modules.Items.Rarities)
local Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)

const ANNOUNCED_RARITIES: { [keyof<typeof(Rarities)>]: true } = {
	["Epic"] = true,
	["Legendary"] = true,
	["Mythic"] = true,
	["Secret"] = true,
}

const RNG = Random.new()

local function rarityHex(color: Color3?): string
	local c = color or Color3.new(1, 1, 1)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function BlockService.init(self: BlockService)
	self.networker = Networker.server.new("BlockService", self, {
		self.openCrate,
	})
end

function BlockService._announceDrop(self: BlockService, player: Player, crateId: number, trailId: number)
	local crate = Blocks.getBlock(crateId)
	if not crate then
		return
	end

	local trail = Trails[trailId]
	if not trail then
		return
	end

	if not ANNOUNCED_RARITIES[trail.trailRarity] then
		return
	end

	local crateName = crate.blockName
	local trailName = trail.trailName
	local trailRarity = trail.trailRarity
	local rarityColor = Rarities[trailRarity]

	local text = string.format(
		"<font color='%s'>[SYSTEM] <b>%s (@%s)</b> unboxed %s [<b>%s</b>] from the <b>%s</b>!</font>",
		rarityHex(rarityColor),
		player.DisplayName,
		player.Name,
		trailName,
		trailRarity,
		crateName
	)

	self.networker:fireAll("announceDrop", text)
	return
end

function BlockService.openCrate(self: BlockService, player: Player): (string, { crateId: number, trailId: number }?)
	local profile = ProfileServiceServer.getProfile(player)
	if not profile then
		return "ERROR", nil
	end

	if profile:getCrateInQueue() == nil then
		return "INVALID_ACTION", nil
	end

	local crateId = profile:getCrateInQueue()

	if profile:getLapsLeftToAcquire() > 0 then
		return "NOT_ENOUGH_LAPS", nil
	end

	local trailId = Blocks.rollTrail(crateId, RNG:NextNumber())
	if not trailId then
		return "ERROR", nil
	end

	profile:setCrateInQueue(nil)

	local nextCrateId = Blocks.rollBlock(RNG:NextNumber())
	if nextCrateId then
		profile:setCrateInQueue(nextCrateId)
	end

	task.delay(Blocks.rollTime + 0.5, function()
		pcall(function()
			self:_announceDrop(player, crateId, trailId)
		end)
	end)

	profile:giveTrail(trailId)

	return "SUCCESS", { crateId = crateId, trailId = trailId }
end

type BlockService = typeof(BlockService) & {
	networker: Networker.Server,
}

return BlockService :: BlockService
