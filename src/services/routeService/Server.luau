local RouteService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker)
local RouteServiceUtils = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceUtils)

local GeneralNotificationsServiceServer = require(ServerScriptService.Services.GeneralNotificationsService.GeneralNotificationsServiceServer)
local GetBestRoute = require(ReplicatedStorage.Shared.Services.RouteService.GetBestRoute)
local PlotServiceServer = require(ServerScriptService.Services.PlotService.PlotServiceServer)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RunnerServiceServer = require(ServerScriptService.Services.RunnerService.RunnerServiceServer)

function RouteService.init(self: RouteService)
	self.networker = Networker.server.new("RouteService", self, {
		self.selectRoute,
	})

	-- Track the best route unlocked by each player's rebirth count so a rebirth
	-- can tell whether their current selection was the previous best (and should
	-- auto-advance) or a manual pick (and must be left alone).
	self.playerJanitors = {}
	self.bestRouteWhenLastChecked = {}

	for _, player in Players:GetPlayers() do
		-- Spawned because _watchRebirths yields on data, which would otherwise
		-- stall the services initialized after this one.
		task.spawn(function()
			self:_watchRebirths(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		self:_watchRebirths(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		-- The janitor is missing when the player left before their data loaded.
		local janitor = self.playerJanitors[player]
		if janitor then
			janitor:Destroy()
		end

		self.playerJanitors[player] = nil
		self.bestRouteWhenLastChecked[player] = nil
	end)
end

--[=[
	Keeps the player on the best route they have unlocked.

	Whenever their rebirth count changes, the strongest route that the new count
	unlocks is resolved. If the player was riding the previously-best route, they
	are moved up automatically; if they had manually selected a different route,
	that choice is preserved. Reaching a stronger route than before also notifies
	the player, since route ownership is derived from rebirths rather than stored,
	so this is the only moment an unlock can be observed.

	@param player Player -- The player to watch
	@return () -- No return value
]=]
function RouteService._watchRebirths(self: RouteService, player: Player)
	-- waitForData yields, so the player may already have left.
	if not DataService:waitForData(player) then
		return
	end

	local profile = ProfileServiceServer.getProfile(player)

	self.bestRouteWhenLastChecked[player] = GetBestRoute(profile:getRebirths())

	local janitor = Janitor.new()
	self.playerJanitors[player] = janitor

	janitor:Add(
		DataService:getChangedSignal(player, "rebirths"):Connect(function()
			local previousBestRoute = self.bestRouteWhenLastChecked[player]
			if not previousBestRoute then
				return
			end

			local newBestRoute = GetBestRoute(profile:getRebirths())

			if newBestRoute == previousBestRoute then
				return
			end

			-- Compared by requirement rather than by id to match how GetBestRoute
			-- ranks routes, so a rebirth count that drops (moving the best route
			-- back down) is not announced as an unlock.
			local unlockedNewRoute = RouteServiceUtils[newBestRoute].rebirthRequirement > RouteServiceUtils[previousBestRoute].rebirthRequirement

			-- Only auto-switch when the player's selection is the previous best;
			-- a manually chosen route below it stays untouched.
			if profile:getRoute() == previousBestRoute then
				self:_applyRoute(player, newBestRoute)
			end

			self.bestRouteWhenLastChecked[player] = newBestRoute

			-- Announced even when the player stays on a manually chosen lower
			-- route, because the new route is unlocked either way.
			if unlockedNewRoute then
				GeneralNotificationsServiceServer:sendNotification(player, `You unlocked Route {newBestRoute}! 🎉`)
			end
		end),
		"Disconnect"
	)
end

function RouteService.selectRoute(self: RouteService, player: Player, routeId: number)
	if not RouteServiceUtils[routeId] then
		return false, "INVALID_ROUTE"
	end

	local profile = ProfileServiceServer.getProfile(player)

	local routeRebirthRequirement = RouteServiceUtils[routeId].rebirthRequirement

	if routeRebirthRequirement > profile:getRebirths() then
		return false, "NOT_ENOUGH_REBIRTHS"
	end

	if not self:_applyRoute(player, routeId) then
		return false, "ERROR"
	end

	return true, "SUCCESS"
end

--[=[
	Writes the route and rebuilds everything that is keyed to it.

	@param player Player -- The player whose route is changing
	@param routeId number -- The route to move the player onto
	@return boolean -- Whether the world was rebuilt for the new route
]=]
function RouteService._applyRoute(_self: RouteService, player: Player, routeId: number): boolean
	local profile = ProfileServiceServer.getProfile(player)

	profile:setRoute(routeId)

	local playerPlot = PlotServiceServer:getPlot(player)
	if not playerPlot then
		return false
	end

	playerPlot:buildRunway(routeId)
	RunnerServiceServer:resetForRouteChange(player)
	playerPlot:rebuildAllGates()

	return true
end

type RouteService = typeof(RouteService) & {
	networker: Networker.Server,
	playerJanitors: { [Player]: Janitor.Janitor },
	bestRouteWhenLastChecked: { [Player]: number },
}

return RouteService :: RouteService
