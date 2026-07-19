local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)

local NotificationServiceServer = {}

function NotificationServiceServer.init(self: NotificationServiceServer)
	self.networker = Networker.server.new("NotificationService", self)
end

function NotificationServiceServer.sendNotification(self: NotificationServiceServer, player: Player, image: string, amount: number): ()
	self.networker:fire(player, "serverNotification", {
		Image = image,
		Amount = amount,
	})
end

type NotificationServiceServer = typeof(NotificationServiceServer) & {
	networker: Networker.Server,
}

return NotificationServiceServer :: NotificationServiceServer
