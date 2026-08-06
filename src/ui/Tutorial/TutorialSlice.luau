const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Charm = require(ReplicatedStorage.Packages.Charm)
const DataService = require(ReplicatedStorage.Packages.DataService).client

const TUTORIAL_FINISHED_PATH = { "tutorial", "finished" }

const isInTutorial = Charm.atom(true)
const localTutorialStage = Charm.atom(1)
const isTutorialFinished = Charm.atom(false)

-- DataService:get() yields until the server replicates data, and this module is
-- reached from a top-level require chain that runs before DataService:init().
-- Reading at module scope would deadlock the client, so mirror the value instead.
task.spawn(function()
	DataService:waitForData()
	isTutorialFinished(DataService:get(TUTORIAL_FINISHED_PATH))
	DataService:getChangedSignal(TUTORIAL_FINISHED_PATH):Connect(function(finished: boolean)
		isTutorialFinished(finished)
	end)
end)

return {
	actions = {},
	states = {
		isInTutorial = isInTutorial,
		isTutorialFinished = isTutorialFinished,
		localTutorialStage = localTutorialStage,
	},
}
