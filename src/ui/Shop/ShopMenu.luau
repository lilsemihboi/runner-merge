--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Codes = require(ReplicatedStorage.Shared.UI.Shop.Frames.Codes)
local Currency = require(ReplicatedStorage.Shared.UI.Shop.Frames.Currency)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local Passes = require(ReplicatedStorage.Shared.UI.Shop.Frames.Passes)
local SpecialOffers = require(ReplicatedStorage.Shared.UI.Shop.Frames.SpecialOffers)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)
const Crates = require(ReplicatedStorage.Shared.UI.Shop.Frames.Crates)

-- ScrollingFrame and Currency section of the currently mounted Shop. Plain
-- references (not sources) because scrolling is a one-shot imperative action, so
-- nothing should re-render when a new Shop mount replaces them.
local scrollingFrame = nil
local cashProductsFrame = nil

-- AutomaticCanvasSize needs at least one layout pass before AbsolutePosition and
-- AbsoluteCanvasSize can be trusted, so poll a bounded number of frames instead
-- of guessing with a fixed debounce or waiting forever.
local LAYOUT_READY_MAX_FRAMES = 30

-- Scrolls the Currency section into view. Runs outside any Vide reactive scope
-- so it is free to yield while waiting for that layout pass.
local function scrollToCashProducts()
	for _ = 1, LAYOUT_READY_MAX_FRAMES do
		local scrollFrame = scrollingFrame
		local currencyFrame = cashProductsFrame
		local isLayoutReady = scrollFrame ~= nil and currencyFrame ~= nil and scrollFrame.AbsoluteSize.Y > 0 and scrollFrame.AbsoluteCanvasSize.Y > 0

		if isLayoutReady then
			-- The player may have closed the Shop or switched menus while we
			-- waited for the layout, so only scroll while it is still open.
			if Menu.openedMenu() ~= "Shop" then
				return
			end

			-- Convert the on-screen gap into canvas units so the section lands
			-- correctly even mid open-animation: UIScale multiplies AbsoluteSize
			-- and AbsolutePosition but not the requested Size or CanvasPosition.
			local pixelsPerCanvasUnit = scrollFrame.AbsoluteSize.Y / scrollFrame.Size.Y.Offset
			local screenGap = currencyFrame.AbsolutePosition.Y - scrollFrame.AbsolutePosition.Y
			local canvasOffset = scrollFrame.CanvasPosition.Y + screenGap / pixelsPerCanvasUnit

			TweenService:Create(
				scrollFrame,
				TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CanvasPosition = Vector2.new(0, math.max(0, canvasOffset)) }
			):Play()

			return
		end

		RunService.Heartbeat:Wait()
	end
end

local function shopContent()
	local currencySection = Currency()

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
			scrollingFrame = inst
			cashProductsFrame = currencySection

			Vide.cleanup(function()
				-- Only surrender the references if this mount still owns them; a
				-- newer mount may have already replaced them.
				if scrollingFrame == inst then
					scrollingFrame = nil
					cashProductsFrame = nil
				end
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
		-- Force-open rather than toggle: switch to the Shop when another menu
		-- (or nothing) is open, and leave it open when it already is.
		if Menu.openedMenu() ~= "Shop" then
			Menu.setOpenedMenu("Shop")
		end

		-- Scrolling waits for the layout to settle, so it must run outside any
		-- reactive scope where yielding is illegal.
		task.spawn(scrollToCashProducts)
	end,
}
