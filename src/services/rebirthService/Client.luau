--!nonstrict

local RebirthService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ErrorMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.ErrorMessage)
local InfoEnums = require(ReplicatedStorage.Shared.Modules.Utils.InfoEnums)
local Networker = require(ReplicatedStorage.Packages.Networker)

function RebirthService.init(self: RebirthService)
	self.networker = Networker.client.new("RebirthService", self)
end

function RebirthService.rebirth(self: RebirthService)
	local result = self.networker:fetch("rebirth")

	if result ~= "SUCCESS" then
		if InfoEnums[result] then
			ErrorMessage.add(InfoEnums[result])
		else
			ErrorMessage.add(InfoEnums.ERROR)
		end
	end
end

type RebirthService = typeof(RebirthService) & {
	networker: Networker.Client,
}

return RebirthService :: RebirthService
