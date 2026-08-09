--!nonstrict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local StockServiceUtils = require(ReplicatedStorage.Shared.Services.StockService.StockServiceUtils)

type MonetizationProduct = {
	id: number,
	key: string?,
	giftId: number?,
	stock: number?,
}

type StockMap = StockServiceUtils.StockMap
type StockOptions = {
	products: { [string]: MonetizationProduct },
}

local PREFIX = RunService:IsStudio() and "__test__" or "__production__"
local DATA_STORE_NAME = PREFIX .. "Stock_v1"
local DATA_STORE_KEY = "GlobalStock"
local REFRESH_INTERVAL = 15

local StockServiceServer = {
	dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME),
}

function StockServiceServer.init(self: StockService, options: StockOptions): ()
	self.options = options
	self.soldCounts = {}
	self.stockedProducts = StockServiceUtils.getStockedProducts(options.products)
	self.networker = Networker.server.new("StockService", self, { self.getStocks })

	task.spawn(function()
		while true do
			self:refresh()
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

--[=[
	Pulls the authoritative sold counts and reconciles them into the cache.

	Reads are served from a short-lived DataStore cache, so a poll can return
	counts older than a sale this server just made. Merging with `math.max`
	keeps the number monotonic instead of letting stock climb back up.
]=]
function StockServiceServer.refresh(self: StockService): ()
	local isSuccessful, result = pcall(function()
		return self.dataStore:GetAsync(DATA_STORE_KEY)
	end)

	if not isSuccessful then
		warn("[StockService] Failed to read stock:", result)
		return
	end

	self:_applySoldCounts(result)
end

function StockServiceServer._applySoldCounts(self: StockService, incoming: StockMap?): ()
	local merged, hasChanged = StockServiceUtils.mergeSoldCounts(self.soldCounts, incoming)
	if not hasChanged then
		return
	end

	self.soldCounts = merged
	self.networker:fireAll("stockChanged", merged)
end

--[=[
	Resolves a Roblox product id to the product key it was configured under.
	Gift ids resolve to the same key so a gifted purchase consumes stock too.

	@param productId number
	@return string?
]=]
function StockServiceServer.getProductKeyFromId(self: StockService, productId: number): string?
	for key, product in self.stockedProducts do
		if product.id == productId or product.giftId == productId then
			return key
		end
	end

	return nil
end

--[=[
	Units still available. Served from memory, so it is safe to call often.

	@param productKey string
	@return number -- math.huge when the product declares no limit
]=]
function StockServiceServer.getRemaining(self: StockService, productKey: string): number
	local product = self.stockedProducts[productKey]
	if not product or not product.stock then
		return math.huge
	end

	return StockServiceUtils.getRemaining(product.stock, self.soldCounts[productKey])
end

--[=[
	@param productKey string
	@return boolean
]=]
function StockServiceServer.isSoldOut(self: StockService, productKey: string): boolean
	return self:getRemaining(productKey) <= 0
end

--[=[
	Records one sold unit for the product behind a Roblox product id.

	Called after a receipt has already been granted, so it never refuses. A
	paid purchase is always honoured and the count is allowed to pass the
	limit; the prompt-time guards are what keep that window small.

	@param productId number
	@return boolean -- false when the id is unstocked or the write failed
]=]
function StockServiceServer.consumeByProductId(self: StockService, productId: number): boolean
	local productKey = self:getProductKeyFromId(productId)
	if not productKey then
		return false
	end

	local isSuccessful, result = pcall(function()
		return self.dataStore:UpdateAsync(DATA_STORE_KEY, function(currentSoldCounts: StockMap?)
			local nextSoldCounts: StockMap = if currentSoldCounts then table.clone(currentSoldCounts) else {}
			nextSoldCounts[productKey] = (nextSoldCounts[productKey] or 0) + 1

			return nextSoldCounts
		end)
	end)

	if not isSuccessful then
		warn("[StockService] Failed to consume stock for", productKey, result)
		return false
	end

	self:_applySoldCounts(result)

	return true
end

--[=[
	Client-callable. Serves the in-memory cache only, never the DataStore, so
	it cannot be used to burn through this server's request budget.

	@return StockMap
]=]
function StockServiceServer.getStocks(self: StockService, _player: Player): StockMap
	return self.soldCounts
end

type StockService = typeof(StockServiceServer) & {
	networker: Networker.Server,
	options: StockOptions,
	soldCounts: StockMap,
	stockedProducts: { [string]: MonetizationProduct },
}

return StockServiceServer :: StockService
