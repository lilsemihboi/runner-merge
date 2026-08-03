--!nonstrict

local InventoryService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ErrorMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.ErrorMessage)
local InfoEnums = require(ReplicatedStorage.Shared.Modules.Utils.InfoEnums)
local Networker = require(ReplicatedStorage.Packages.Networker)

function InventoryService.init(self: InventoryService)
	self.networker = Networker.client.new("InventoryService", self)
end

function InventoryService.selectTrail(self: InventoryService, trailId: number?)
	local success, response = self.networker:fetch("selectTrail", trailId)

	if not success then
		if InfoEnums[response] then
			ErrorMessage.add(InfoEnums[response])
		else
			ErrorMessage.add(InfoEnums.ERROR)
		end
	end
end

type InventoryService = typeof(InventoryService) & {
	networker: Networker.Client,
}

return InventoryService :: InventoryService
