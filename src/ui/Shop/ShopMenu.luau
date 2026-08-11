--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Codes = require(ReplicatedStorage.Shared.UI.Shop.Frames.Codes)
local Currency = require(ReplicatedStorage.Shared.UI.Shop.Frames.Currency)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local Passes = require(ReplicatedStorage.Shared.UI.Shop.Frames.Passes)
local SpecialOffers = require(ReplicatedStorage.Shared.UI.Shop.Frames.SpecialOffers)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)
const Crates = require(ReplicatedStorage.Shared.UI.Shop.Frames.Crates)

local scrollingFrame = Vide.source(nil)
local cashProductsFrame = Vide.source(nil)
local pendingScrollToCash = Vide.source(false)

Vide.root(function(_destructor)
	Vide.effect(function()
		local isMenuOpen = Vide.untrack(Menu.openedMenu) == "Shop"
		local pending = pendingScrollToCash()
		local sf = scrollingFrame()
		local target = cashProductsFrame()

		if not isMenuOpen or not pending or not sf or not target then
			return
		end

		task.wait(0.02)

		local relativeY = target.AbsolutePosition.Y - sf.AbsolutePosition.Y + sf.CanvasPosition.Y

		TweenService
			:Create(sf, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CanvasPosition = Vector2.new(0, math.max(0, relativeY)) })
			:Play()

		pendingScrollToCash(false) -- reset after scroll
	end)
end)

local function shopContent()
	local currencySection = Currency()
	cashProductsFrame(currencySection)

	return Vide.create("ScrollingFrame", {
		Size = usePx.offset(1008, 686),
		Position = usePx.udim2(0, 0, 0, 116),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,

		Vide.action(function(inst)
			scrollingFrame(inst)
			Vide.cleanup(function()
				scrollingFrame(nil)
			end)
		end),

		Vide.create("UIListLayout", {
			Padding = UDim.new(0, 0),
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),

		SpecialOffers(),
		Crates(),
		Passes(),
		currencySection,
		Codes(),
	})
end

return {
	menuId = "Shop",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "Shop",
			Title = "Shop",
			Scale = 1,

			shopContent(),
		})
	end,
	openCashProducts = function()
		pendingScrollToCash(true) -- flag that we want to scroll
		Menu.setOpenedMenu("Shop")
	end,
}
