local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StockSlice = require(ReplicatedStorage.Shared.Services.StockService.StockSlice)
local VideCharm = require(ReplicatedStorage.Packages.VideCharm)

--[=[
	Reactive count of units still available for a stocked product.

	`useSignalState` binds the subscription to the calling Vide scope, so the
	listener is disposed along with the component that created it.

	@param productKey string
	@return () -> number
]=]
return function(productKey: string): () -> number
	return VideCharm.useSignalState(function()
		return StockSlice.getRemaining(productKey)
	end)
end
