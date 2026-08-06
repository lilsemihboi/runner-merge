--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Configuration = require(ReplicatedStorage.Shared.Modules.Game.Configuration)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local FriendServiceClient = require(ReplicatedStorage.Shared.Services.FriendService.FriendServiceClient)
local HudSlice = require(script.Parent.HudSlice)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local ShopMenu = require(ReplicatedStorage.Shared.UI.Shop.ShopMenu)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local VideCharm = require(ReplicatedStorage.Packages.VideCharm)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)
const TutorialSlice = require(ReplicatedStorage.Shared.UI.Tutorial.TutorialSlice)

local CashBar = {}
local hiddenReward = Vide.source(0)
local hiddenRewardBaseCash = Vide.source(nil)

function CashBar.setHiddenReward(reward: number, baseCash: number)
	if typeof(reward) ~= "number" or reward <= 0 or typeof(baseCash) ~= "number" then
		return
	end

	hiddenReward(reward)
	hiddenRewardBaseCash(baseCash)
end

function CashBar.showHiddenReward()
	hiddenReward(0)
	hiddenRewardBaseCash(nil)
end

local function inviteFriends()
	SocialService:PromptGameInvite(Players.LocalPlayer)
end

function CashBar.Component()
	local cash = getVideDataSource("cash")
	local displayedCash = Vide.source(cash())
	local friendsCount = VideCharm.useAtom(FriendServiceClient.friendCount)
	local cashBarPositionTarget = Vide.derive(function()
		if Menu.openedMenu() == nil then
			return usePx.udim2(0, 12, 1, 0)()
		end

		return UDim2.fromScale(-1, 1)
	end)
	local cashBarPosition = Vide.spring(cashBarPositionTarget, 0.35, 0.8)

	const isTutorialFinished = VideCharm.useAtom(TutorialSlice.states.isTutorialFinished)
	const localTutorialStage = VideCharm.useAtom(TutorialSlice.states.localTutorialStage)

	-- The cash text sits beside the "+" button while it is shown and slides
	-- back to the bar's left edge once it is hidden.
	local isCashButtonVisible = Vide.derive(function()
		return isTutorialFinished() or localTutorialStage() >= 10
	end)
	local cashTextPositionBesideButton = usePx.udim2(0, 90, 0, 45)
	local cashTextPositionAtEdge = usePx.udim2(0, 4, 0, 45)

	local appliedHiddenReward = 0
	local canSendFriendInvites = SocialService:CanSendGameInviteAsync(Players.LocalPlayer)

	Vide.effect(function()
		local latestCash = cash()
		local requestedHiddenReward = hiddenReward()
		local baseCash = hiddenRewardBaseCash()

		if requestedHiddenReward <= 0 then
			appliedHiddenReward = 0
		elseif (typeof(baseCash) == "number" and latestCash >= baseCash + requestedHiddenReward) or appliedHiddenReward > requestedHiddenReward then
			-- Keep the previous offset until the server has credited the larger
			-- reward (for example, while a double-purchase receipt is processing).
			appliedHiddenReward = requestedHiddenReward
		end

		displayedCash(math.max(latestCash - appliedHiddenReward, 0))
	end)

	return Frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Size = usePx.offset(333, 150),
		Position = cashBarPosition,
		Visible = function()
			if HudSlice.showEverything() == false then
				return false
			else
				return true
			end
		end,
		--Invite friend container
		Frame({
			BackgroundTransparency = 1,
			Size = usePx.offset(333, 45),

			-- Friend boost +0%
			TextLabel({
				Size = usePx.offset(260, 45),
				Position = usePx.udim2(0, 9, 0, 0),
				Text = function()
					return `Friend boost +{friendsCount() * Configuration.FRIENDS_PER_TICK}%`
				end,
				TextScaled = true,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Stroke = {
					Thickness = usePx(3),
				},
				Font = Enum.Font.BuilderSansExtraBold,
			}),

			-- Plus Icon Invite Friend
			-- 269 + 24 padding that should give button size
			StudButton({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Visible = canSendFriendInvites,
				Size = usePx.offset(40, 40),
				Colors = ButtonColors.Green,
				Position = usePx.udim2(0, 300, 0, 20),
				Text = "+",
				TextSize = usePx(60),
				OnClick = inviteFriends,
			} :: StudButton.StudButton),
		}),

		-- Plus Icon Cash Products
		-- sits at the left edge; the cash text starts right after it so the
		-- left-aligned text never leaves a gap between itself and the button
		StudButton({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0, 40, 0, 90),
			Size = usePx.offset(54, 54),
			Colors = ButtonColors.Green,
			Text = "+",
			TextSize = usePx(64),
			OnClick = function()
				ShopMenu.openCashProducts()
			end,
			Visible = isCashButtonVisible,
		} :: StudButton.StudButton),

		TextLabel({
			Position = function()
				return if isCashButtonVisible() then cashTextPositionBesideButton() else cashTextPositionAtEdge()
			end,
			TextScaled = true,
			Size = usePx.offset(309, 90),
			Text = function()
				return `${Abbreviate(displayedCash())}`
			end,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Stroke = {
				Thickness = usePx(5),
			},
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Gradient = {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 230, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 230, 0)),
				}),
				Rotation = 270,
				Enabled = true,
			},
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		}),
	})
end

return CashBar
