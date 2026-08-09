--[=[
	Stock is persisted as the number of units *sold*, never as the number
	remaining. Two properties fall out of that choice:

	1. There is no bootstrap write. An absent key simply means zero sold, so a
	   server that starts late can never reset stock back to full.
	2. Sold counts only ever increase, so a stale read can be reconciled with
	   `math.max` instead of being trusted blindly. Storing "remaining" would
	   let a cached read make stock visibly climb back up.

	The limit itself lives on the product in `Products.luau`, so changing it is
	a code deploy rather than a data migration.

	This module is intentionally dependency-free so it stays pure and testable.
]=]

local StockServiceUtils = {}

export type StockMap = { [string]: number }

-- Structural, so this module does not have to depend on MonetizationService
-- just to borrow a type.
type StockedProduct = { stock: number? }

--[=[
	Returns the units still available for a product.

	@param limit number -- Lifetime limit from the product config
	@param soldCount number? -- Units sold so far
	@return number -- Never negative, even if we oversold
]=]
function StockServiceUtils.getRemaining(limit: number, soldCount: number?): number
	return math.max(0, limit - (soldCount or 0))
end

--[=[
	Filters a product table down to the entries that declare a stock limit.

	@param products { [string]: T }
	@return { [string]: T }
]=]
function StockServiceUtils.getStockedProducts<T>(products: { [string]: T & StockedProduct }): { [string]: T & StockedProduct }
	local stockedProducts: { [string]: T & StockedProduct } = {}

	for key, product in products do
		if product.stock then
			stockedProducts[key] = product
		end
	end

	return stockedProducts
end

--[=[
	Merges an incoming sold-count map into the current one, keeping the highest
	value seen for each key.

	DataStore reads are cached for a few seconds, so a poll can legitimately
	return counts older than what this server already wrote.

	@param current StockMap
	@param incoming StockMap?
	@return (StockMap, boolean) -- The merged map, and whether anything changed
]=]
function StockServiceUtils.mergeSoldCounts(current: StockMap, incoming: StockMap?): (StockMap, boolean)
	if not incoming then
		return current, false
	end

	local merged: StockMap = table.clone(current)
	local hasChanged = false

	for key, soldCount in incoming do
		if typeof(soldCount) ~= "number" then
			continue
		end

		local highest = math.max(merged[key] or 0, soldCount)
		if merged[key] ~= highest then
			merged[key] = highest
			hasChanged = true
		end
	end

	return merged, hasChanged
end

return StockServiceUtils
