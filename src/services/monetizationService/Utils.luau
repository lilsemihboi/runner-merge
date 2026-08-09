export type GiftData = {
	fromUserId: number,
	productKey: string,
	date: number,
}

export type MonetizationProduct = {
	id: number,
	key: string?,
	giftId: number?,
	isPass: boolean?,
	oneTimePurchase: boolean?,
	purchaseCooldown: number?,
	random: boolean?,
	disabled: boolean?,
	-- Lifetime purchase limit shared across every server. Enforced by
	-- StockService, which gates the purchase prompt rather than the receipt.
	stock: number?,
	callback: ((Player) -> ())?,
}

export type Gamepasses = {
	[number]: boolean?,
}

return nil
