--!nonstrict
local UtilitiesService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local NotificationMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.NotificationMessage)

type NotificationProps = {
	Prefix: {
		Image: string,
	}?,
}

function UtilitiesService.init(self: UtilitiesService)
	self.networker = Networker.client.new("UtilitiesService", self)
end

function UtilitiesService.displayNotification(_self: UtilitiesService, text: string, props: NotificationProps?)
	NotificationMessage.add({
		Text = text,
		RichText = true,
		Prefix = if props then props.Prefix else nil,
	})
end

type UtilitiesService = typeof(UtilitiesService) & {
	networker: Networker.Client,
}

return UtilitiesService :: UtilitiesService
