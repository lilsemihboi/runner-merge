local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonetizationServiceUtils = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceUtils)

type MonetizationProduct = MonetizationServiceUtils.MonetizationProduct

local products = {
	--------------------------------
	-- 	  -    PRODUCTS    -      --
	--------------------------------

	doubleOfflineEarnings = {
		id = 3609107348,
	} :: MonetizationProduct,

	starterPack = {
		id = 3609866032,
		oneTimePurchase = true,
	} :: MonetizationProduct,

	carBundle1 = {
		id = 3609863241,
	} :: MonetizationProduct,

	x5Spin = {
		id = 3609863143,
		random = true,
	} :: MonetizationProduct,

	x3Spin = {
		id = 3609863090,
		random = true,
	} :: MonetizationProduct,

	x1Spin = {
		id = 3609862993,
		random = true,
	} :: MonetizationProduct,

	extraGate1 = {
		id = 3609858039,
	} :: MonetizationProduct,

	extraGate2 = {
		id = 3609858087,
	} :: MonetizationProduct,

	cashPack1 = {
		id = 3609857753,
	} :: MonetizationProduct,

	cashPack2 = {
		id = 3609857642,
	} :: MonetizationProduct,

	cashPack3 = {
		id = 3609857532,
	} :: MonetizationProduct,

	cashPack4 = {
		id = 3609857146,
	} :: MonetizationProduct,

	--------------------------------
	-- 	  --     PASSES    --     --
	--------------------------------

	vip = {
		id = 1908932677,
		isPass = true,
	} :: MonetizationProduct,

	x2Speed = {
		id = 1907576707,
		isPass = true,
	} :: MonetizationProduct,

	x2Cash = {
		id = 1906304732,
		isPass = true,
	} :: MonetizationProduct,
}

return products :: { [keyof<typeof(products)>]: MonetizationProduct }
