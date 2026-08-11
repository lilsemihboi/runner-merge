local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local StockServiceUtils = require(ReplicatedStorage.Shared.Services.StockService.StockServiceUtils)

type StockMap = StockServiceUtils.StockMap

--[=[
	Replicated sold counts, keyed by product key. Absent means zero sold.

	Charm freezes signal values in Studio, so every write must publish a fresh
	table rather than mutating the current one in place.
]=]
local soldCounts = Charm.atom({} :: StockMap)

--[=[
	Whether `soldCounts` reflects the server yet.

	An empty `soldCounts` is ambiguous: it means either "nothing sold" or "not
	replicated yet". Callers that gate content on stock need to tell those apart,
	otherwise a sold-out product looks available for the first frames of a join.
]=]
local isSynced = Charm.atom(false)

local StockSlice = {
	actions = {
		setSoldCounts = function(nextSoldCounts: StockMap)
			-- Flag first so `soldCounts` subscribers already see a trustworthy
			-- `isSynced` while they run.
			isSynced(true)
			soldCounts(table.clone(nextSoldCounts))
		end,

		reset = function()
			isSynced(false)
			soldCounts({})
		end,
	},

	states = {
		soldCounts = soldCounts,
		isSynced = isSynced,
	},
}

--[=[
	Units still available for a stocked product.

	@param productKey string
	@return number -- math.huge when the product declares no limit
]=]
function StockSlice.getRemaining(productKey: string): number
	local product = (Products :: any)[productKey]
	local limit = product and product.stock

	if not limit then
		return math.huge
	end

	return StockServiceUtils.getRemaining(limit, soldCounts()[productKey])
end

--[=[
	@param productKey string
	@return boolean
]=]
function StockSlice.isSoldOut(productKey: string): boolean
	return StockSlice.getRemaining(productKey) <= 0
end

return StockSlice
