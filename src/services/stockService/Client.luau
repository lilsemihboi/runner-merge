--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local StockServiceUtils = require(ReplicatedStorage.Shared.Services.StockService.StockServiceUtils)
local StockSlice = require(ReplicatedStorage.Shared.Services.StockService.StockSlice)

type StockMap = StockServiceUtils.StockMap

local StockServiceClient = {}

function StockServiceClient.init(self: StockService): ()
	self.networker = Networker.client.new("StockService", self)

	self:refresh()
end

--[=[
	Pulls the current sold counts from the server. The server answers from its
	own cache, so this is cheap and safe to call on demand.
]=]
function StockServiceClient.refresh(self: StockService): ()
	task.spawn(function()
		local soldCounts = self.networker:fetch("getStocks")
		if typeof(soldCounts) ~= "table" then
			return
		end

		StockSlice.actions.setSoldCounts(soldCounts)
	end)
end

--[=[
	Server push whenever a sold count changes on any server.

	@param soldCounts StockMap
]=]
function StockServiceClient.stockChanged(_self: StockService, soldCounts: StockMap): ()
	StockSlice.actions.setSoldCounts(soldCounts)
end

--[=[
	@param productKey string
	@return number -- math.huge when the product declares no limit
]=]
function StockServiceClient.getRemaining(_self: StockService, productKey: string): number
	return StockSlice.getRemaining(productKey)
end

--[=[
	@param productKey string
	@return boolean
]=]
function StockServiceClient.isSoldOut(_self: StockService, productKey: string): boolean
	return StockSlice.isSoldOut(productKey)
end

type StockService = typeof(StockServiceClient) & {
	networker: Networker.Client,
}

return StockServiceClient :: StockService
