--!strict

--[[
	Client half of analytics.

	Neither Roblox `AnalyticsService` nor the Gamebeast Markers API can be
	called from the client, so this only forwards events to the server, which
	validates and emits them.

	Everything sent from here is therefore untrusted by definition. The server
	re-checks product keys and reason codes, and throttles per player.
]]

const AnalyticsService = {}

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const GameBeast = require(ReplicatedStorage.Packages.GameBeast)
const Networker = require(ReplicatedStorage.Packages.Networker)
const Markers = require(script.Parent.Markers)
const OnboardingFunnel = require(script.Parent.OnboardingFunnel)

function AnalyticsService.init(self: AnalyticsService)
	self.networker = Networker.client.new("AnalyticsService", self)

	GameBeast:Setup()
end

function AnalyticsService.logOnboardingStep(self: AnalyticsService, step: number): ()
	if OnboardingFunnel.getStepName(step) == nil then
		return
	end

	self.networker:fire("logOnboardingStep", step)
end

--[[
	Convenience wrapper for the tutorial, which thinks in stages 1-13 rather
	than funnel steps. Unknown stages are dropped rather than guessed at.
]]
function AnalyticsService.logTutorialStage(self: AnalyticsService, stage: number): ()
	const step = OnboardingFunnel.fromTutorialStage(stage)

	if not step then
		return
	end

	self:logOnboardingStep(step)
end

function AnalyticsService.logStoreOpened(self: AnalyticsService, source: string): ()
	self.networker:fire("logStoreOpened", source)
end

--[[
	Fired when the player asks to buy something, before the game decides whether
	to prompt. Paired with `logPurchaseStarted`, the gap between the two is the
	set of purchases the game refused -- sold out, on cooldown, already owned.

	`productKey` is optional because `MonetizationProduct.key` is back-filled at
	init rather than declared in the product table. A nil key is dropped instead
	of guessed at, so a marker can never be attributed to the wrong product.
]]
function AnalyticsService.logProductViewed(self: AnalyticsService, productKey: string?): ()
	if not productKey then
		return
	end

	self.networker:fire("logProductViewed", productKey)
end

--[[
	Fired once the Roblox purchase prompt is actually on screen.
]]
function AnalyticsService.logPurchaseStarted(self: AnalyticsService, productKey: string?): ()
	if not productKey then
		return
	end

	self.networker:fire("logPurchaseStarted", productKey)
end

--[[
	Fired when the game refused to prompt, or the player dismissed the prompt.

	Best-effort only. Purchase success is reported by the server from the
	receipt, never from here.
]]
function AnalyticsService.logPurchaseDeclined(self: AnalyticsService, productKey: string?, reason: string): ()
	if not productKey then
		return
	end

	self.networker:fire("logPurchaseDeclined", productKey, reason)
end

AnalyticsService.failureReasons = Markers.failureReasons
AnalyticsService.storeSources = Markers.storeSources

type AnalyticsService = typeof(AnalyticsService) & {
	networker: Networker.Client,
}

return AnalyticsService :: AnalyticsService
