local RouteService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)

function RouteService.init(self: RouteService)
	self.networker = Networker.server.new("RouteService", self, {
		self.selectRoute,
	})
end

function RouteService.selectRoute(_self: RouteService, player: Player, routeId: number)
	--TODO: Check Rebirth requirement
	local profile = ProfileServiceServer.getProfile(player)

	profile:setRoute(routeId)
	return
end

type RouteService = typeof(RouteService) & {
	networker: Networker.Server,
}

return RouteService :: RouteService
