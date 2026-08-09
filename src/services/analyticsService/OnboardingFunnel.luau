--!strict

--[[
	Shared definition of the tutorial onboarding funnel.

	Both the client (which detects step completion) and the server (which emits
	the analytics event) read from this table, so step numbers and display names
	can never drift apart between the two.

	Funnel steps are completion-based: funnel step N fires *after* the player
	finishes the corresponding action, per Roblox analytics guidance.
]]

const OnboardingFunnel = {}

--[[
	Funnel step number -> display name.

	These names are sent to AnalyticsService and shown on the Creator Dashboard.
	Renaming one mid-flight puts a warning on the dashboard and splits the
	reported data, so treat existing entries as frozen once published.
]]
OnboardingFunnel.stepNames = {
	[1] = "Joined Game",
	[2] = "Tutorial Started",
	[3] = "Step 01 - Bought First Gate Upgrade",
	[4] = "Step 02 - Bought First Car",
	[5] = "Step 03 - Earned First Cash From Gate",
	[6] = "Step 04 - Owned Three Cars",
	[7] = "Step 05 - Merged Two Cars",
	[8] = "Step 06 - Completed Laps To Unlock Crate",
	[9] = "Step 07 - Opened Crate",
	[10] = "Step 08 - Opened Inventory Menu",
	[11] = "Step 09 - Equipped Trail",
	[12] = "Step 10 - Saved 1000 Cash",
	[13] = "Step 11 - Opened Rebirth Menu",
	[14] = "Step 12 - Completed First Rebirth",
	[15] = "Step 13 - Tutorial Finished",
}

OnboardingFunnel.playerJoined = 1
OnboardingFunnel.tutorialStarted = 2
OnboardingFunnel.lastStep = 15

--[[
	Tutorial stage 1-13 maps onto funnel steps 3-15, because funnel steps 1 and 2
	cover joining the game and reaching a usable plot before the tutorial runs.

	Returns nil for out-of-range input so callers fail closed rather than
	emitting a step that has no name.
]]
function OnboardingFunnel.fromTutorialStage(stage: number): number?
	const step = stage + 2

	if OnboardingFunnel.stepNames[step] == nil then
		return nil
	end

	return step
end

function OnboardingFunnel.getStepName(step: number): string?
	return OnboardingFunnel.stepNames[step]
end

return OnboardingFunnel
