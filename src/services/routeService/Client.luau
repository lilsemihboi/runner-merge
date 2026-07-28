--!nonstrict

local RouteService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ErrorMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.ErrorMessage)
local InfoEnums = require(ReplicatedStorage.Shared.Modules.Utils.InfoEnums)
local Networker = require(ReplicatedStorage.Packages.Networker)

function RouteService.init(self: RouteService)
	self.networker = Networker.client.new("RouteService", self)
end

function RouteService.selectRoute(self: RouteService, routeId: number)
	local success, response = self.networker:fetch("selectRoute", routeId)

	if not success then
		if InfoEnums[response] then
			ErrorMessage.add(InfoEnums[response])
		else
			ErrorMessage.add(InfoEnums.ERROR)
		end
	end
end

type RouteService = typeof(RouteService) & {
	networker: Networker.Client,
}

return RouteService :: RouteService
