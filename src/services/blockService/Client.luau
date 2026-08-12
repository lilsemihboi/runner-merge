--!nonstrict

local BlockService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local CratesSlice = require(ReplicatedStorage.Shared.UI.Crates.CratesSlice)
local ErrorMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.ErrorMessage)
local GetDataSource = require(ReplicatedStorage.Shared.Modules.Ui.Sources.GetDataSource)
local InfoEnums = require(ReplicatedStorage.Shared.Modules.Utils.InfoEnums)
local Networker = require(ReplicatedStorage.Packages.Networker)

function BlockService.init(self: BlockService)
	self.networker = Networker.client.new("BlockService", self)
end

function BlockService.announceDrop(_self: BlockService, text: string): ()
	TextChatService.TextChannels:FindFirstChild("RBXGeneral"):DisplaySystemMessage(text)
	return
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

function BlockService.openCrate(self: BlockService): ()
	if GetDataSource({ "luckyBlockInQueue" })() == nil then
		ErrorMessage.add(InfoEnums.INVALID_ACTION)
		return
	end

	if GetDataSource({ "lapsLeftToAcquire" })() > 0 then
		ErrorMessage.add(InfoEnums.NOT_ENOUGH_LAPS)
		return
	end

	local response, rewardData = self.networker:fetch("openCrate")

	if response ~= "SUCCESS" then
		if InfoEnums[response] then
			ErrorMessage.add(InfoEnums[response])
		else
			ErrorMessage.add(InfoEnums.ERROR)
		end

		return
	end

	CratesSlice.actions.beginRolling(rewardData)
	return
end

type BlockService = typeof(BlockService) & {
	networker: Networker.Client,
}

return BlockService :: BlockService
