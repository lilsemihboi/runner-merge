const TutorialService = {}

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
const Networker = require(ReplicatedStorage.Packages.Networker)

function TutorialService.init(self: TutorialService)
	self.networker = Networker.server.new("TutorialService", self, {
		self.saveStage,
	})
end

function TutorialService.saveStage(_self: TutorialService, player: Player, stage: number): ()
	if typeof(stage) ~= "number" then
		return
	end

	if stage > 255 then
		return
	end

	local profile = ProfileServiceServer.getProfile(player)
	profile:stepTutorial(stage)

	return
end

function TutorialService.finishTutorial(_self: TutorialService, player: Player): ()
	local profile = ProfileServiceServer.getProfile(player)
	profile:finishTutorial()

	return
end

type TutorialService = typeof(TutorialService) & {
	networker: Networker.Server,
}

return TutorialService :: TutorialService
