local RouteService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)

function RouteService.init(self: RouteService)
	self.networker = Networker.client.new("RouteService", self)
end

type RouteService = typeof(RouteService) & {
	networker: Networker.Client,
}

return RouteService :: RouteService
