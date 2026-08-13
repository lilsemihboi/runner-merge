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

-- The shop re-mounts from scratch on every open, its sections auto-size, and the
-- menu's open-spring keeps rescaling everything on top of that, so AbsolutePosition
-- and AbsoluteCanvasSize take several layout passes to settle. Poll a bounded
-- number of frames rather than guessing with a fixed debounce.
local LAYOUT_READY_MAX_FRAMES = 120

-- The section's canvas offset can drift a sub-pixel between frames once settled
-- (integer AbsolutePosition rounding), so treat readings this close as steady.
local LAYOUT_STABLE_TOLERANCE = 1

-- Returns the Currency section's top expressed as a CanvasPosition.Y, or nil
-- while the layout has not produced trustworthy measurements yet.
local function getCurrencyCanvasOffset(scrollFrame, currencyFrame): number?
	if scrollFrame.AbsoluteSize.Y <= 0 or scrollFrame.AbsoluteCanvasSize.Y <= 0 then
		return nil
	end

	-- Convert the on-screen gap into canvas units: UIScale multiplies AbsoluteSize
	-- and AbsolutePosition but not the requested Size or CanvasPosition, so this
	-- stays constant across the open-animation and settles exactly when the section
	-- stops moving within the canvas, no matter how far the spring has scaled it.
	local pixelsPerCanvasUnit = scrollFrame.AbsoluteSize.Y / scrollFrame.Size.Y.Offset
	local screenGap = currencyFrame.AbsolutePosition.Y - scrollFrame.AbsolutePosition.Y

	return scrollFrame.CanvasPosition.Y + screenGap / pixelsPerCanvasUnit
end

-- Scrolls the Currency section into view. Runs outside any Vide reactive scope
-- so it is free to yield while waiting for the layout to settle.
local function scrollToCashProducts()
	local previousOffset = nil

	for frame = 1, LAYOUT_READY_MAX_FRAMES do
		-- The player may have closed the Shop or switched menus while we waited,
		-- so stop as soon as it is no longer the open menu.
		if Menu.openedMenu() ~= "Shop" then
			return
		end

		local scrollFrame = scrollingFrame
		local currencyFrame = cashProductsFrame
		local canvasOffset = if scrollFrame ~= nil and currencyFrame ~= nil then getCurrencyCanvasOffset(scrollFrame, currencyFrame) else nil

		if canvasOffset ~= nil then
			-- Wait until the target holds steady between frames (or fall back on
			-- the final polled frame) so the tween never commits to a half-settled
			-- layout and leaves the section only partly scrolled into view.
			local isSettled = previousOffset ~= nil and math.abs(canvasOffset - previousOffset) <= LAYOUT_STABLE_TOLERANCE

			if isSettled or frame == LAYOUT_READY_MAX_FRAMES then
				TweenService:Create(
					scrollFrame,
					TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CanvasPosition = Vector2.new(0, math.max(0, canvasOffset)) }
				):Play()

				return
			end

			previousOffset = canvasOffset
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
