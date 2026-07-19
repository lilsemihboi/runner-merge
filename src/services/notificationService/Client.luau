local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Notifications = require(ReplicatedStorage.Shared.UI.App.Components.Notifications)
local NotificationServiceClient = {}

function NotificationServiceClient.init(self: NotificationServiceClient)
	self.networker = Networker.client.new("NotificationService", self)
end

function NotificationServiceClient:serverNotification(props)
	Notifications.addNotification(props)
end

type NotificationServiceClient = typeof(NotificationServiceClient) & {
	networker: Networker.Client,
}

return NotificationServiceClient :: NotificationServiceClient
