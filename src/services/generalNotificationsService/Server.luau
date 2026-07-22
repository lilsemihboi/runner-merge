local UtilitiesService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)

function UtilitiesService.init(self: UtilitiesService)
	self.networker = Networker.server.new("UtilitiesService", self)
end

function UtilitiesService.sendNotification(self: UtilitiesService, player: Player, text: string)
	self.networker:fire(player, "displayNotification", text)
end

type UtilitiesService = typeof(UtilitiesService) & {
	networker: Networker.Server,
}

return UtilitiesService :: UtilitiesService
