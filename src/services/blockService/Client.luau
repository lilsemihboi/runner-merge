--!nonstrict

local BlockService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

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

	print(rewardData)
	--TODO: Pass the reward data to ui component
end

type BlockService = typeof(BlockService) & {
	networker: Networker.Client,
}

return BlockService :: BlockService
