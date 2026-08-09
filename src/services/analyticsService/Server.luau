--!strict

--[[
	Emits tutorial onboarding funnel events.

	AnalyticsService can only be called from the server, and only in a published
	place, so the client detects tutorial progress and reports it here. Because
	the client is the trigger, every incoming step is treated as untrusted and
	validated before it reaches AnalyticsService.
]]

const AnalyticsService = {}

const Analytics = game:GetService("AnalyticsService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const Networker = require(ReplicatedStorage.Packages.Networker)
const DataService = require(ReplicatedStorage.Packages.DataService).server
-- Lives in ReplicatedStorage rather than alongside this script, since the Rojo
-- tree splits Server.luau into ServerScriptService and shares the rest.
const OnboardingFunnel = require(ReplicatedStorage.Shared.Services.AnalyticsService.OnboardingFunnel)

const TUTORIAL_FINISHED_PATH = { "tutorial", "finished" }

--[[
	Studio and unpublished places silently drop analytics events. Logging them
	anyway would be harmless but makes the output window noisy during testing,
	so they are skipped and reported once at startup instead.
]]
const isAnalyticsAvailable = not RunService:IsStudio()

function AnalyticsService.init(self: AnalyticsService)
	self.loggedStepsByPlayer = {}

	self.networker = Networker.server.new("AnalyticsService", self, {
		self.logOnboardingStep,
	})

	-- Players present before this service initialised would otherwise never
	-- enter the funnel at all. Spawned so a slow data load cannot stall the
	-- rest of the server's startup.
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_startOnboardingFunnel(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		self:_startOnboardingFunnel(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.loggedStepsByPlayer[player] = nil
	end)

	if not isAnalyticsAvailable then
		warn("[AnalyticsService] Running in Studio; funnel events will not be sent.")
	end
end

--[[
	Enters the player into the funnel on join.

	Players who already finished the tutorial are deliberately excluded. Funnel
	entry is cohort-attributed to the day the first step is logged, and existing
	players have no funnel history at all, so logging their join would place the
	whole returning playerbase in this week's cohort at step 1 with no way to
	ever reach step 2. That would bury the real new-user drop-off under noise.

	Players still mid-tutorial are included, since they genuinely can still
	complete onboarding and we want their progress counted.
]]
function AnalyticsService._startOnboardingFunnel(self: AnalyticsService, player: Player)
	DataService:waitForData(player)

	-- waitForData yields, so the player may already have left.
	if not player.Parent then
		return
	end

	if DataService:get(player, TUTORIAL_FINISHED_PATH) then
		return
	end

	self:_logStep(player, OnboardingFunnel.playerJoined)
end

--[[
	Called by the client once it has finished a funnel step. The step number is
	validated against the shared name table, so an exploiter cannot invent steps
	or push the funnel past its defined range.
]]
function AnalyticsService.logOnboardingStep(self: AnalyticsService, player: Player, step: number): ()
	if typeof(step) ~= "number" then
		return
	end

	if step ~= step or step % 1 ~= 0 then
		return
	end

	if OnboardingFunnel.getStepName(step) == nil then
		warn(`[AnalyticsService] Rejected invalid funnel step {step} from {player.Name}.`)
		return
	end

	self:_logStep(player, step)
end

--[[
	Repeated steps are ignored by the funnel itself, but they still count toward
	the global analytics rate limit, so they are filtered out per player here.
]]
function AnalyticsService._logStep(self: AnalyticsService, player: Player, step: number): ()
	local loggedSteps = self.loggedStepsByPlayer[player]

	if not loggedSteps then
		loggedSteps = {}
		self.loggedStepsByPlayer[player] = loggedSteps
	end

	if loggedSteps[step] then
		return
	end

	loggedSteps[step] = true

	if not isAnalyticsAvailable then
		return
	end

	const stepName = OnboardingFunnel.getStepName(step)

	const success, problem = pcall(function()
		Analytics:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)

	if not success then
		warn(`[AnalyticsService] Failed to log funnel step {step} for {player.Name}: {problem}`)
	end
end

type AnalyticsService = typeof(AnalyticsService) & {
	networker: Networker.Server,
	loggedStepsByPlayer: { [Player]: { [number]: boolean } },
}

return AnalyticsService :: AnalyticsService
