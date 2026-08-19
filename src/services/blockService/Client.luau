--!nonstrict

local BlockService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)
local CratesSlice = require(ReplicatedStorage.Shared.UI.Crates.CratesSlice)
local ErrorMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.ErrorMessage)
local GetDataSource = require(ReplicatedStorage.Shared.Modules.Ui.Sources.GetDataSource)
local InfoEnums = require(ReplicatedStorage.Shared.Modules.Utils.InfoEnums)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Signal = require(ReplicatedStorage.Packages.Signal)

local autoRollStateChanged = Signal.new()
local crateRollStatusChanged = Signal.new()

function BlockService.init(self: BlockService)
	self.networker = Networker.client.new("BlockService", self)
end

function BlockService.announceDrop(_self: BlockService, text: string): ()
	TextChatService.TextChannels:FindFirstChild("RBXGeneral"):DisplaySystemMessage(text)
	return
end

function BlockService.updateAutoRollState(_self: BlockService, enabled: boolean): ()
	autoRollStateChanged:Fire(enabled)
end

function BlockService.getAutoRollState(self: BlockService): boolean
	return self.networker:fetch("getAutoRollState") == true
end

function BlockService.toggleAutoRoll(self: BlockService): (string, boolean)
	return self.networker:fetch("toggleAutoRoll")
end

--[=[
	Starts the reel for crates bought with Robux. The server has already rolled and granted
	every reward, so there is nothing to ask for and no lap requirement to check: the screen
	opens and starts spinning as soon as the receipt is processed.
]=]
function BlockService.beginPurchasedRolls(_self: BlockService, rolls: { CratesSlice.Roll }): ()
	if type(rolls) ~= "table" or #rolls == 0 then
		return
	end

	CratesSlice.actions.beginRollQueue(rolls)
	return
end

function BlockService._openCrate(self: BlockService, isAutoRoll: boolean): (string, CratesSlice.Roll?)
	if GetDataSource({ "luckyBlockInQueue" })() == nil then
		ErrorMessage.add(InfoEnums.INVALID_ACTION)
		return "INVALID_ACTION", nil
	end

	if GetDataSource({ "lapsLeftToAcquire" })() > 0 then
		ErrorMessage.add(InfoEnums.NOT_ENOUGH_LAPS)
		return "NOT_ENOUGH_LAPS", nil
	end

	if isAutoRoll then
		crateRollStatusChanged:Fire("Rolling...", nil)
	end
	local response, rewardData = self.networker:fetch(if isAutoRoll then "openAutoCrate" else "openCrate")

	if response ~= "SUCCESS" then
		if isAutoRoll then
			crateRollStatusChanged:Fire(nil, nil)
		end
		if not isAutoRoll and InfoEnums[response] then
			ErrorMessage.add(InfoEnums[response])
		elseif not isAutoRoll then
			ErrorMessage.add(InfoEnums.ERROR)
		end

		return response, nil
	end

	if isAutoRoll then
		task.delay(Blocks.rollTime, function()
			crateRollStatusChanged:Fire("ROLLED", rewardData)
		end)
	else
		CratesSlice.actions.beginRolling(rewardData)
	end
	return response, rewardData
end

function BlockService.openCrate(self: BlockService): ()
	self:_openCrate(false)
	return
end

function BlockService.openAutoCrate(self: BlockService): (string, CratesSlice.Roll?)
	return self:_openCrate(true)
end

type BlockService = typeof(BlockService) & {
	networker: Networker.Client,
	autoRollStateChanged: Signal.Signal<boolean>,
	crateRollStatusChanged: Signal.Signal<string?, CratesSlice.Roll?>,
}

BlockService.autoRollStateChanged = autoRollStateChanged
BlockService.crateRollStatusChanged = crateRollStatusChanged

return BlockService :: BlockService
