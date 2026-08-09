--!strict

--[[
	Client half of the tutorial onboarding funnel.

	AnalyticsService cannot be called from the client, so this only forwards
	completed steps to the server, which validates and emits them.
]]

const AnalyticsService = {}

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Networker = require(ReplicatedStorage.Packages.Networker)
const OnboardingFunnel = require(script.Parent.OnboardingFunnel)

function AnalyticsService.init(self: AnalyticsService)
	self.networker = Networker.client.new("AnalyticsService", self)
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

type AnalyticsService = typeof(AnalyticsService) & {
	networker: Networker.Client,
}

return AnalyticsService :: AnalyticsService
