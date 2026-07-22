local UtilitiesService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local NotificationMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.NotificationMessage)

function UtilitiesService.init(self: UtilitiesService)
	self.networker = Networker.client.new("UtilitiesService", self)
end

function UtilitiesService.displayNotification(_self: UtilitiesService, text: string)
	NotificationMessage.add({ Text = text })
end

type UtilitiesService = typeof(UtilitiesService) & {
	networker: Networker.Client,
}

return UtilitiesService :: UtilitiesService
