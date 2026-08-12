--!nonstrict

local BlockService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)
local FormatNameWithIcons = require(ReplicatedStorage.Shared.Modules.Ui.FormatNameWithIcons)
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

-- Robux crates never enter the lap-gated queue, so a purchase is capped rather than trusted
-- to whatever amount a caller passes.
const MAX_PURCHASED_ROLLS = 10

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
		"<font color='%s'><b>[SYSTEM]</b> <b>%s (@%s)</b> unboxed %s [<b>%s</b>] from the <b>%s</b>!</font>",
		rarityHex(rarityColor),
		FormatNameWithIcons(player),
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

--[=[
	Opens crates that were paid for with Robux.

	Purchased crates deliberately bypass the lap gate and the `luckyBlockInQueue` slot: the
	player bought this specific crate, so neither their lap progress nor whatever crate the
	track happens to be holding is relevant. Rewards are rolled and granted here, then pushed
	to the client so the reel starts the moment the receipt is processed.

	@param player Player
	@param crateId number -- The crate the product maps to.
	@param amount number -- How many rolls the product grants.
	@return boolean -- False when nothing could be granted, so the caller can soft-fail.
]=]
function BlockService.grantPurchasedCrate(self: BlockService, player: Player, crateId: number, amount: number): boolean
	local profile = ProfileServiceServer.getProfile(player)
	if not profile then
		return false
	end

	local crate = Blocks.getBlock(crateId)
	if not crate or not crate.loot then
		warn("[grantPurchasedCrate] unknown crateId", crateId)
		return false
	end

	local rollCount = math.clamp(math.floor(amount), 1, MAX_PURCHASED_ROLLS)
	local rolls = table.create(rollCount)

	for _ = 1, rollCount do
		local trailId = Blocks.rollTrail(crateId, RNG:NextNumber())
		if trailId then
			profile:giveTrail(trailId)
			table.insert(rolls, { crateId = crateId, trailId = trailId })
		end
	end

	if #rolls == 0 then
		return false
	end

	self.networker:fire(player, "beginPurchasedRolls", rolls)

	-- Announcements are staggered to land as each roll finishes on the client's reel rather
	-- than spoiling every drop the instant the purchase clears.
	for index, roll in rolls do
		task.delay(Blocks.rollTime + 0.5 + (index - 1) * (Blocks.rollTime + Blocks.revealHold), function()
			pcall(function()
				self:_announceDrop(player, roll.crateId, roll.trailId)
			end)
		end)
	end

	return true
end

type BlockService = typeof(BlockService) & {
	networker: Networker.Server,
}

return BlockService :: BlockService
