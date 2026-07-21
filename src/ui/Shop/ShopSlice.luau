--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationServiceUtils = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceUtils)
local Vide = require(ReplicatedStorage.Packages.Vide)

type GiftReceivedData = {
	product: MonetizationServiceUtils.MonetizationProduct,
	giftData: MonetizationServiceUtils.GiftData,
}

local giftingProduct: Vide.Source<any?> = Vide.source(nil)
local giftReceivedData: Vide.Source<GiftReceivedData?> = Vide.source(nil)

local actions = {}

return {
	state = {
		giftingProduct = giftingProduct,
		giftReceivedData = giftReceivedData,
	},
	actions = actions,
}
