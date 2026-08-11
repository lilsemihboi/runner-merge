local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RouteServiceUtils = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceUtils)

local FALLBACK_ROUTE_ID = 1

--[=[
	Resolves the strongest route a rebirth count has unlocked.

	Routes are ranked by `rebirthRequirement` instead of by id so the answer stays
	correct if a future route is added out of order; ids only break ties. Route 1
	is the fallback because it requires zero rebirths, so a player always has one
	route available.

	@param rebirths number -- The rebirth count to resolve against
	@return number -- The unlocked route with the highest rebirth requirement
]=]
return function(rebirths: number): number
	local bestRouteId = FALLBACK_ROUTE_ID
	local bestRequirement = -1

	for routeId, route in RouteServiceUtils do
		if route.rebirthRequirement > rebirths then
			continue
		end

		local outranksBest = route.rebirthRequirement > bestRequirement
		local breaksTie = route.rebirthRequirement == bestRequirement and routeId > bestRouteId

		if outranksBest or breaksTie then
			bestRouteId = routeId
			bestRequirement = route.rebirthRequirement
		end
	end

	return bestRouteId
end
