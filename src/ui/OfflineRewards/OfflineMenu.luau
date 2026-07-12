--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Comma = require(ReplicatedStorage.Shared.Modules.Ui.Comma)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local OfflineEarningsServiceClient = require(ReplicatedStorage.Shared.Services.OfflineEarningsService.OfflineEarningsServiceClient)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local RobuxButton = require(ReplicatedStorage.Shared.UI.App.Components.RobuxButton)
local Slice = require(ReplicatedStorage.Shared.Services.OfflineEarningsService.OfflineEarningsSlice)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local COUNT_UP_DURATION = 3
local COUNT_UP_INTERVAL = 0.1

local function offlineMenu()
	local pendingReward = Slice.pendingReward
	local hasDoubledReward = getVideDataSource("offlineEarningsDoubled")
	local isDoublePurchasePromptOpen = Slice.isDoublePurchasePromptOpen
	local openedMenu = Menu.openedMenu
	local canDoubleReward = Vide.derive(function()
		return pendingReward() ~= nil and hasDoubledReward() ~= true
	end)

	local coins = Vide.derive(function()
		local reward = pendingReward()

		-- The receipt callback replaces the pending reward with its doubled value.
		-- `offlineEarningsDoubled` only controls whether another purchase is allowed.
		return if typeof(reward) == "number" then reward else 0
	end)

	local displayedCoins = Vide.source(0)
	local animationToken = 0
	local previousTarget = 0
	local wasOpen = false

	Vide.effect(function()
		local target = coins()
		local isOpen = openedMenu() == "OfflineRewards"
		local isPromptOpen = isDoublePurchasePromptOpen()

		-- The receipt can reach the client before Roblox closes its purchase
		-- prompt. Keep the original amount on screen until that prompt closes.
		if isPromptOpen then
			return
		end

		animationToken += 1
		local currentToken = animationToken

		if not isOpen then
			wasOpen = false
			previousTarget = 0
			displayedCoins(0)
			return
		end

		local start
		if not wasOpen then
			start = 0
			wasOpen = true
		else
			start = previousTarget
		end

		previousTarget = target

		if target <= 0 then
			displayedCoins(0)
			return
		end

		task.spawn(function()
			local startedAt = os.clock()

			while animationToken == currentToken do
				local progress = math.min((os.clock() - startedAt) / COUNT_UP_DURATION, 1)

				displayedCoins(math.floor(start + (target - start) * progress))

				if progress >= 1 then
					displayedCoins(target)
					break
				end

				task.wait(COUNT_UP_INTERVAL)
			end
		end)

		Vide.cleanup(function()
			if animationToken == currentToken then
				animationToken += 1
			end
		end)
	end)

	local previousMenu = openedMenu()

	Vide.effect(function()
		local newMenu = openedMenu()

		if previousMenu == "OfflineRewards" and (newMenu ~= "OfflineRewards" and pendingReward() ~= nil) then
			task.defer(function()
				OfflineEarningsServiceClient:claimWhenReady()
			end)
		end

		previousMenu = newMenu
	end)

	return Frame({
		Size = usePx.offset(1008 * 0.75, 686 * 0.75),
		Position = usePx.udim2(0, 0, 0, 116 * 0.75),
		BackgroundTransparency = 1,

		-- You have earned [1/4]:
		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 44),
			Text = "You have earned:",
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Size = usePx.offset(576, 57),
			Stroke = {
				Thickness = usePx(4),
				Color = Color3.fromRGB(0, 0, 0),
			},
			TextColor3 = Color3.fromRGB(255, 255, 255),
		}),

		-- $ Cash amount (using commas) [2/4]:
		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 130),
			Text = function()
				return `${Comma(displayedCoins())}`
			end,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextScaled = true,
			Size = usePx.offset(658, 105),
			Stroke = {
				Thickness = usePx(5),
				Color = Color3.fromRGB(0, 0, 0),
			},
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Vide.create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(152, 221, 2)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(76, 237, 2)),
				}),
			}),
		}),

		-- Would you like to double it? [3/4]:
		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, 275),
			Text = "Would you like to double it?",
			Visible = canDoubleReward,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextScaled = true,
			Size = usePx.offset(673, 57),
			Stroke = {
				Thickness = usePx(5),
				Color = Color3.fromRGB(0, 0, 0),
			},
			TextColor3 = Color3.fromRGB(255, 255, 255),

			Vide.create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(2, 199, 237)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(2, 160, 237)),
				}),
			}),
		}),

		RobuxButton({
			Colors = ButtonColors.Green,
			product = Products.doubleOfflineEarnings,
			Visible = canDoubleReward,
			OnPurchaseRequested = function()
				return OfflineEarningsServiceClient:beginDoublePurchase()
			end,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = usePx.offset(284, 93),
			Position = usePx.udim2(0.5, 0, 0, 425),
		} :: RobuxButton.RobuxButtonProps),
	})
end

return {
	menuId = "OfflineRewards",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "OfflineRewards",
			Title = "Welcome Back!",
			Scale = 0.75,

			offlineMenu(),
		})
	end,
}
