--!nonstrict

local BlockService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)
local DataService = require(ReplicatedStorage.Packages.DataService).server
local FormatNameWithIcons = require(ReplicatedStorage.Shared.Modules.Ui.FormatNameWithIcons)
local GeneralNotificationsServiceServer = require(ServerScriptService.Services.GeneralNotificationsService.GeneralNotificationsServiceServer)
local MonetizationServiceServer = require(ServerScriptService.Services.MonetizationService.MonetizationServiceServer)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
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
		self.openAutoCrate,
		self.getAutoRollState,
		self.toggleAutoRoll,
	})
	self.playersOpeningCrates = {}

	MonetizationServiceServer.gamePassAwarded:Connect(function(player: Player, product)
		if product ~= Products.autoRollCrate then
			return
		end

		DataService:set(player, "autoCrateOpen", true)
		self.networker:fire(player, "updateAutoRollState", true)
		GeneralNotificationsServiceServer:sendNotification(player, "Auto Roll enabled!")
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self.playersOpeningCrates[player] = nil
	end)
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
		"<font color='%s'><b>[SYSTEM]</b> <b>%s (@%s)</b> rolled %s [<b>%s</b>] from the <b>%s</b>!</font>",
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

function BlockService._notifyAutoDrop(_self: BlockService, player: Player, trailId: number, shouldNotify: boolean)
	if not shouldNotify then
		return
	end

	local trail = Trails[trailId]
	if trail then
		local rarityColor = rarityHex(Rarities[trail.trailRarity])
		GeneralNotificationsServiceServer:sendNotification(
			player,
			`Auto Roll rolled <font color='{rarityColor}'><b>{trail.trailName}</b> [{trail.trailRarity}]</font>!`
		)
	end
end

function BlockService._openCrate(self: BlockService, player: Player, wasAutoRoll: boolean): (string, { crateId: number, trailId: number }?)
	if self.playersOpeningCrates[player] then
		return "INVALID_ACTION", nil
	end
	self.playersOpeningCrates[player] = true

	local profile = ProfileServiceServer.getProfile(player)
	if not profile then
		self.playersOpeningCrates[player] = nil
		return "ERROR", nil
	end

	if profile:getCrateInQueue() == nil then
		self.playersOpeningCrates[player] = nil
		return "INVALID_ACTION", nil
	end

	local crateId = profile:getCrateInQueue()

	if profile:getLapsLeftToAcquire() > 0 then
		self.playersOpeningCrates[player] = nil
		return "NOT_ENOUGH_LAPS", nil
	end

	local trailId = Blocks.rollTrail(crateId, RNG:NextNumber())
	if not trailId then
		self.playersOpeningCrates[player] = nil
		return "ERROR", nil
	end

	local trail = Trails[trailId]
	local selectedTrail = Trails[profile:getSelectedTrail()]
	local isBetterThanSelected = trail ~= nil and (selectedTrail == nil or trail.trailMultiplier > selectedTrail.trailMultiplier)
	local shouldNotify = trail ~= nil and (ANNOUNCED_RARITIES[trail.trailRarity] == true or (wasAutoRoll and isBetterThanSelected))

	profile:setCrateInQueue(nil)

	local nextCrateId = Blocks.rollBlock(RNG:NextNumber())
	if nextCrateId then
		profile:setCrateInQueue(nextCrateId)
	end

	task.delay(Blocks.rollTime + 0.5, function()
		pcall(function()
			if trail ~= nil and ANNOUNCED_RARITIES[trail.trailRarity] then
				self:_announceDrop(player, crateId, trailId)
			end
			if wasAutoRoll then
				self:_notifyAutoDrop(player, trailId, shouldNotify)
			end
		end)
	end)

	profile:giveTrail(trailId)
	if wasAutoRoll then
		task.delay(Blocks.rollTime + Blocks.revealHold, function()
			self.playersOpeningCrates[player] = nil
		end)
	else
		self.playersOpeningCrates[player] = nil
	end

	return "SUCCESS", { crateId = crateId, trailId = trailId }
end

function BlockService.openCrate(self: BlockService, player: Player): (string, { crateId: number, trailId: number }?)
	return self:_openCrate(player, false)
end

function BlockService.openAutoCrate(self: BlockService, player: Player): (string, { crateId: number, trailId: number }?)
	if DataService:get(player, "autoCrateOpen") ~= true or not MonetizationServiceServer:ownsGamepass(player, Products.autoRollCrate) then
		return "INVALID_ACTION", nil
	end

	return self:_openCrate(player, true)
end

function BlockService.getAutoRollState(_self: BlockService, player: Player): boolean
	return DataService:get(player, "autoCrateOpen") == true and MonetizationServiceServer:ownsGamepass(player, Products.autoRollCrate)
end

function BlockService.toggleAutoRoll(self: BlockService, player: Player): (string, boolean)
	if not MonetizationServiceServer:ownsGamepass(player, Products.autoRollCrate) then
		return "NOT_OWNED", false
	end

	local enabled = DataService:get(player, "autoCrateOpen") ~= true
	DataService:set(player, "autoCrateOpen", enabled)
	self.networker:fire(player, "updateAutoRollState", enabled)
	GeneralNotificationsServiceServer:sendNotification(player, if enabled then "Auto Roll enabled!" else "Auto Roll disabled.")
	return "SUCCESS", enabled
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
		local trail = Trails[roll.trailId]
		task.delay(Blocks.rollTime + 0.5 + (index - 1) * (Blocks.rollTime + Blocks.revealHold), function()
			pcall(function()
				if trail ~= nil and ANNOUNCED_RARITIES[trail.trailRarity] then
					self:_announceDrop(player, roll.crateId, roll.trailId)
				end
			end)
		end)
	end

	return true
end

type BlockService = typeof(BlockService) & {
	networker: Networker.Server,
	playersOpeningCrates: { [Player]: boolean? },
}

return BlockService :: BlockService
