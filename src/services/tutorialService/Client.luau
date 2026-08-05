const TutorialService = {}

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Networker = require(ReplicatedStorage.Packages.Networker)

function TutorialService.init(self: TutorialService)
	self.networker = Networker.client.new("TutorialService", self)
end

function TutorialService.saveStage(self: TutorialService, stage: number): ()
	if typeof(stage) ~= "number" then
		return
	end

	if stage > 255 then
		return
	end

	self.networker:fire("saveStage", stage)
end

function TutorialService.finishTutorial(self: TutorialService): ()
	self.networker:fire("finishTutorial")
	return
end

type TutorialService = typeof(TutorialService) & {
	networker: Networker.Client,
}

return TutorialService :: TutorialService
