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
		giftId = 3610794683,
	} :: MonetizationProduct,

	x5Spin = {
		id = 3609863143,
		random = true,
		giftId = 3610794799,
	} :: MonetizationProduct,

	x3Spin = {
		id = 3609863090,
		random = true,
		giftId = 3610794881,
	} :: MonetizationProduct,

	x1Spin = {
		id = 3609862993,
		random = true,
	} :: MonetizationProduct,

	extraGate1 = {
		id = 3609858039,
	} :: MonetizationProduct,

	skipRebirth = {
		id = 3612182563,
	} :: MonetizationProduct,

	extraGate2 = {
		id = 3609858087,
	} :: MonetizationProduct,
	--
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

	--------- Crates

	crate1 = { random = true, id = 3703612993 } :: MonetizationProduct,

	crate2 = { random = true, id = 3703613988 } :: MonetizationProduct,

	crate3 = { random = true, id = 3703614930 } :: MonetizationProduct,

	x3crate1 = {
		random = true,
		id = 3703758478,
	} :: MonetizationProduct,

	x3crate2 = {
		random = true,
		id = 3703773886,
	} :: MonetizationProduct,

	x3crate3 = {
		random = true,
		id = 3703775270,
	} :: MonetizationProduct,

	adHeartCrate = {
		random = true,
		id = 3710757101,
	},

	-- Exclusive Stocked Products
	exclusiveCar = {
		id = 3637359531,
		stock = 1_000,
		giftId = 3675691634,
	} :: MonetizationProduct,

	--------------------------------
	-- 	  --     PASSES    --     --
	--------------------------------

	vip = {
		id = 1908932677,
		isPass = true,
		giftId = 3610794991,
	} :: MonetizationProduct,

	x2Speed = {
		id = 1907576707,
		isPass = true,
		giftId = 3610795081,
	} :: MonetizationProduct,

	x2Cash = {
		id = 1906304732,
		isPass = true,
		giftId = 3610795184,
	} :: MonetizationProduct,

	autoRollCrate = {
		id = 1952750474,
		isPass = true,
		giftId = 3708891779,
	} :: MonetizationProduct,
}

return products :: { [keyof<typeof(products)>]: MonetizationProduct }
