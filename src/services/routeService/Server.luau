local RouteService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Networker = require(ReplicatedStorage.Packages.Networker)

local PlotServiceServer = require(ServerScriptService.Services.PlotService.PlotServiceServer)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RunnerServiceServer = require(ServerScriptService.Services.RunnerService.RunnerServiceServer)

function RouteService.init(self: RouteService)
	self.networker = Networker.server.new("RouteService", self, {
		self.selectRoute,
	})
end

function RouteService.selectRoute(_self: RouteService, player: Player, routeId: number)
	if not ReplicatedStorage.Assets.Runways:FindFirstChild(`Runway{routeId}`) then
		return false, "INVALID_ROUTE"
	end

	-- TODO: Check rebirth requirement

	local profile = ProfileServiceServer.getProfile(player)
	profile:setRoute(routeId)

	local playerPlot = PlotServiceServer:getPlot(player)
	if not playerPlot then
		return false, "ERROR"
	end

	playerPlot:buildRunway(routeId)
	RunnerServiceServer:resetForRouteChange(player)
	playerPlot:rebuildAllGates(playerPlot.profile:getUpgradeLevel("gates"))

	return true, "SUCCESS"
end

type RouteService = typeof(RouteService) & {
	networker: Networker.Server,
}

return RouteService :: RouteService
