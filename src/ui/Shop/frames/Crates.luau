--!nonstrict

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ShopContentFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopContentFrame)

const function exclusiveCrate() end

const function container() end

return function()
	return ShopContentFrame({
		Text = "~Crates~",
		LayoutOrder = 2,
		Padding = 5,

		exclusiveCrate(),
		container(),
	})
end
