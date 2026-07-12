--!nonstrict

local Client = {}

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CashBar = require(ReplicatedStorage.Shared.UI.Hud.CashBar)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local Slice = require(script.Parent.OfflineEarningsSlice)

local DataServiceClient = require(ReplicatedStorage.Packages.DataService).client

function Client:_openMenuIfNeeded(data)
	if typeof(data) ~= "number" or data <= 0 then
		return
	end

	if Menu.openedMenu() ~= "OfflineRewards" then
		Menu.setOpenedMenu("OfflineRewards", true)
	end

	self:_beginReward()
end

function Client:_beginReward()
	if self.isBeginningReward or self.rewardHasBegun then
		return
	end

	self.isBeginningReward = true
	self.offlineRewardCashBaseline = DataServiceClient:get("cash")
	task.spawn(function()
		local success, _, reward = self.networker:fetch("requestBegin")
		self.isBeginningReward = false
		self.rewardHasBegun = success == true

		if success == true then
			self:_setHiddenOfflineReward(reward)
		end

		if self.claimAfterRewardBegins then
			self.claimAfterRewardBegins = false
			self:claimWhenReady()
		end
	end)
end

function Client:_setHiddenOfflineReward(reward: number?)
	local baseCash = self.offlineRewardCashBaseline
	if typeof(reward) ~= "number" or reward <= 0 or typeof(baseCash) ~= "number" then
		return
	end

	CashBar.setHiddenReward(reward, baseCash)
end

function Client:_claimAfterDoublePurchaseIfNeeded()
	if not self.claimAfterDoublePurchase then
		return
	end

	self.claimAfterDoublePurchase = false
	self:claimWhenReady()
end

function Client:init()
	self.networker = Networker.client.new("OfflineEarnings", self)
	self.releaseToken = 0
	self.isBeginningReward = false
	self.rewardHasBegun = false
	self.isDoublePurchasePending = false
	self.isDoublePurchasePromptOpen = false
	self.claimAfterRewardBegins = false
	self.claimAfterDoublePurchase = false
	self.offlineRewardCashBaseline = nil
	Slice.actions.setDoublePurchasePromptOpen(false)

	if self.pendingRewardChangedConn then
		self.pendingRewardChangedConn:Disconnect()
	end

	local initialReward = DataServiceClient:get("offlineEarnings")

	Slice.actions.setPendingReward(initialReward)

	self.pendingRewardChangedConn = DataServiceClient:getChangedSignal("offlineEarnings"):Connect(function(newRewardData)
		Slice.actions.setPendingReward(newRewardData)
		self:_setHiddenOfflineReward(newRewardData)

		if typeof(newRewardData) == "number" and newRewardData > 0 then
			self:_openMenuIfNeeded(newRewardData)
		else
			self.rewardHasBegun = false
		end
	end)

	if self.doubledChangedConn then
		self.doubledChangedConn:Disconnect()
	end

	self.doubledChangedConn = DataServiceClient:getChangedSignal("offlineEarningsDoubled"):Connect(function(isDoubled)
		if isDoubled == true then
			self:_setHiddenOfflineReward(DataServiceClient:get("offlineEarnings"))

			if not self.isDoublePurchasePromptOpen then
				self.isDoublePurchasePending = false
				self:_claimAfterDoublePurchaseIfNeeded()
			end
		end
	end)

	if self.productPurchaseFinishedConn then
		self.productPurchaseFinishedConn:Disconnect()
	end

	self.productPurchaseFinishedConn = MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
		if userId ~= Players.LocalPlayer.UserId or productId ~= Products.doubleOfflineEarnings.id then
			return
		end

		self.isDoublePurchasePromptOpen = false
		Slice.actions.setDoublePurchasePromptOpen(false)

		if not wasPurchased or DataServiceClient:get("offlineEarningsDoubled") == true then
			self.isDoublePurchasePending = false
			self:_claimAfterDoublePurchaseIfNeeded()
		end
	end)

	task.defer(function()
		self:_openMenuIfNeeded(initialReward)
	end)
end

function Client:beginDoublePurchase(): boolean
	local reward = DataServiceClient:get("offlineEarnings")
	if self.isDoublePurchasePending or typeof(reward) ~= "number" or reward <= 0 or DataServiceClient:get("offlineEarningsDoubled") == true then
		return false
	end

	self.isDoublePurchasePending = true
	self.isDoublePurchasePromptOpen = true
	Slice.actions.setDoublePurchasePromptOpen(true)
	return true
end

function Client:claimWhenReady()
	if self.isBeginningReward then
		self.claimAfterRewardBegins = true
		return
	end

	if self.isDoublePurchasePending then
		self.claimAfterDoublePurchase = true
		return
	end

	self:claim()
end

function Client:claim()
	local pendingReward = DataServiceClient:get("offlineEarnings")

	if self.isReleasing then
		return true, nil, pendingReward
	end

	if not pendingReward then
		if Menu.openedMenu() == "OfflineRewards" then
			Menu.setOpenedMenu(nil)
		end

		return false, "No offline earnings to claim", nil
	end

	local success, errorMessage, claimedReward = self.networker:fetch("requestClaim")

	if not success then
		if errorMessage == "NO_REWARD" then
			print("There aren't any offline earnings to claim right now.")
		else
			print(errorMessage or "Offline earnings couldn't be claimed.")
		end

		return false, errorMessage, nil
	end

	self.isReleasing = true
	self.releaseToken = self.releaseToken + 1

	local currentReleaseToken = self.releaseToken

	Slice.actions.clearPendingReward()
	self.rewardHasBegun = false
	self.offlineRewardCashBaseline = nil
	CashBar.showHiddenReward()

	task.delay(1.2, function()
		if self.releaseToken ~= currentReleaseToken then
			return
		end

		self.isReleasing = false
	end)

	if Menu.openedMenu() == "OfflineRewards" then
		Menu.setOpenedMenu(nil)
	end

	return true, nil, claimedReward or pendingReward
end

return Client
