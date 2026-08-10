const TutorialService = {}

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const AnalyticsServiceServer = require(ServerScriptService.Services.AnalyticsService.AnalyticsServiceServer)
const ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
const Markers = require(ReplicatedStorage.Shared.Services.AnalyticsService.Markers)
const Networker = require(ReplicatedStorage.Packages.Networker)

const MAX_TUTORIAL_STAGE = 255

function TutorialService.init(self: TutorialService)
	self.highestReportedStageByPlayer = {}

	self.networker = Networker.server.new("TutorialService", self, {
		self.saveStage,
		self.finishTutorial,
	})

	Players.PlayerRemoving:Connect(function(player)
		self.highestReportedStageByPlayer[player] = nil
	end)
end

function TutorialService.saveStage(self: TutorialService, player: Player, stage: number): ()
	if typeof(stage) ~= "number" then
		return
	end

	if stage > MAX_TUTORIAL_STAGE then
		return
	end

	local profile = ProfileServiceServer.getProfile(player)
	profile:stepTutorial(stage)

	self:_reportStage(player, stage)

	return
end

--[[
	Emits tutorial progress markers.

	Only forward progress is reported. The client drives the tutorial and can
	re-send a stage it has already passed, which would otherwise show up on the
	dashboard as players looping back through onboarding.
]]
function TutorialService._reportStage(self: TutorialService, player: Player, stage: number): ()
	const highestReported = self.highestReportedStageByPlayer[player]

	if highestReported and stage <= highestReported then
		return
	end

	if not highestReported then
		AnalyticsServiceServer:sendPlayerMarker(player, Markers.tutorialStarted, true)
	end

	self.highestReportedStageByPlayer[player] = stage

	AnalyticsServiceServer:sendPlayerMarker(player, Markers.tutorialStep, stage)
end

function TutorialService.finishTutorial(_self: TutorialService, player: Player): ()
	local profile = ProfileServiceServer.getProfile(player)
	profile:finishTutorial()

	AnalyticsServiceServer:sendPlayerMarker(player, Markers.tutorialFinished, true)

	return
end

type TutorialService = typeof(TutorialService) & {
	networker: Networker.Server,
	highestReportedStageByPlayer: { [Player]: number },
}

return TutorialService :: TutorialService
