--!strict

--[[
	Analytics for the game, across two independent transports.

	1. Roblox `AnalyticsService` -- the tutorial onboarding funnel that feeds the
	   Creator Dashboard. Only works in a published place, so it is gated on
	   `isRobloxAnalyticsAvailable`.
	2. Gamebeast markers -- the rich event stream behind our own dashboards.
	   These DO send from Studio, so they are deliberately not gated.

	The two are kept separate on purpose: a Studio playtest should populate
	Gamebeast without emitting funnel noise that the Creator Dashboard would
	silently discard anyway.

	Anything arriving from the client is untrusted and validated here before it
	reaches either transport.
]]

const AnalyticsService = {}

const Analytics = game:GetService("AnalyticsService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const ServerStorage = game:GetService("ServerStorage")

const GameBeast = require(ReplicatedStorage.Packages.GameBeast)
const Networker = require(ReplicatedStorage.Packages.Networker)
const DataService = require(ReplicatedStorage.Packages.DataService).server
const ExclusiveCars = require(ReplicatedStorage.Shared.Modules.Items.ExclusiveCars)
const Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
const RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)
-- Lives in ReplicatedStorage rather than alongside this script, since the Rojo
-- tree splits Server.luau into ServerScriptService and shares the rest.
const Markers = require(ReplicatedStorage.Shared.Services.AnalyticsService.Markers)
const OnboardingFunnel = require(ReplicatedStorage.Shared.Services.AnalyticsService.OnboardingFunnel)

--[[
	`Products` is keyed by literal product names, but client input is an
	arbitrary string until validated, so lookups go through a permissive view.

	Routed via `any` because the source type uses `keyof<...>`, which some
	analyzer builds cannot resolve; a direct cast then fails against the
	resulting error type.
]]
const productsByKey = (Products :: any) :: { [string]: { id: number } }

const TUTORIAL_FINISHED_PATH = { "tutorial", "finished" }

const PROGRESSION_SNAPSHOT_INTERVAL = 60

--[[
	Client markers are player-triggered UI events, so a real player cannot
	produce them faster than they can tap. Anything above this is either lag
	compensation or an exploiter, and is dropped rather than billed to the
	marker quota.
]]
const CLIENT_MARKER_MIN_INTERVAL = 0.2

--[[
	Failed marker batches are retried once from memory. The buffer is bounded so
	a sustained Gamebeast outage degrades into dropped analytics rather than a
	server running out of memory.
]]
const MAX_BUFFERED_FAILED_MARKERS = 2_000
const FAILED_MARKER_RETRY_DELAY = 30

--[[
	Studio and unpublished places silently drop Roblox analytics events. Logging
	them anyway would be harmless but makes the output window noisy during
	testing, so they are skipped and reported once at startup instead.

	This gate applies ONLY to Roblox `AnalyticsService`. Gamebeast markers send
	from Studio and must not be filtered through it.
]]
const isRobloxAnalyticsAvailable = not RunService:IsStudio()

function AnalyticsService.init(self: AnalyticsService)
	self.loggedStepsByPlayer = {}
	self.joinClockByPlayer = {}
	self.lastClientMarkerClockByPlayer = {}
	self.bufferedFailedMarkers = {}

	-- Annotated because Networker's `ClientAccess` is a homogeneous array type:
	-- without it Luau infers the element type from the first entry and then
	-- rejects every later method whose signature differs. The type is not
	-- exported by the package, so it is restated here.
	const clientAccess: { (...any?) -> ...any? } = {
		self.logOnboardingStep,
		self.logStoreOpened,
		self.logProductViewed,
		self.logPurchaseStarted,
		self.logPurchaseDeclined,
	}

	self.networker = Networker.server.new("AnalyticsService", self, clientAccess)

	GameBeast:Setup({
		key = require(ServerStorage.dotenv).GAMEBEAST_API_KEY :: string,
	})

	-- Resolved once rather than per call: `GetService` walks the SDK's module
	-- registry, and markers are sent from hot-ish paths like merges.
	self.markers = GameBeast:GetService("Markers")

	self:_watchFailedMarkers()

	-- Players present before this service initialised would otherwise never
	-- enter the funnel at all. Spawned so a slow data load cannot stall the
	-- rest of the server's startup.
	for _, player in Players:GetPlayers() do
		self.joinClockByPlayer[player] = os.clock()

		task.spawn(function()
			self:_startOnboardingFunnel(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		self.joinClockByPlayer[player] = os.clock()
		self:_startOnboardingFunnel(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Final snapshot before the data leaves memory, so a session that ends
		-- mid-interval still reports where the player finished.
		self:sendProgressionSnapshot(player)

		self.loggedStepsByPlayer[player] = nil
		self.joinClockByPlayer[player] = nil
		self.lastClientMarkerClockByPlayer[player] = nil
	end)

	self:_startProgressionSnapshots()

	if not isRobloxAnalyticsAvailable then
		warn("[AnalyticsService] Running in Studio; Roblox funnel events will not be sent. Gamebeast markers still send.")
	end
end

--[[
	Sends a marker attached to a specific player.

	Every Gamebeast call in the game funnels through here so the SDK handle,
	the pcall, and the failure logging exist in exactly one place.
]]
function AnalyticsService.sendPlayerMarker(self: AnalyticsService, player: Player, markerType: string, value: MarkerValue): ()
	if not self.markers then
		return
	end

	const success, problem = pcall(function()
		self.markers:SendPlayerMarker(player, markerType, value)
	end)

	if not success then
		warn(`[AnalyticsService] Failed to send player marker "{markerType}": {problem}`)
	end
end

--[[
	Sends a server-wide marker with no player attribution.
]]
function AnalyticsService.sendMarker(self: AnalyticsService, markerType: string, value: MarkerValue): ()
	if not self.markers then
		return
	end

	const success, problem = pcall(function()
		self.markers:SendMarker(markerType, value)
	end)

	if not success then
		warn(`[AnalyticsService] Failed to send marker "{markerType}": {problem}`)
	end
end

--[[
	Reports a granted developer product purchase to Gamebeast.

	Gamepasses are deliberately absent: the SDK's own `PurchaseAnalytics` hooks
	`PromptGamePassPurchaseFinished` and reports those itself, so sending them
	here would double-count revenue.

	Must only be called once a purchase is actually granted. Roblox retries a
	receipt until it is granted, so calling this on the `NotProcessedYet` path
	would inflate revenue once per retry, forever.
]]
function AnalyticsService.sendPurchaseGranted(self: AnalyticsService, receiptInfo: { [string]: any }): ()
	if not self.markers then
		return
	end

	const success, problem = pcall(function()
		self.markers:SendNewPurchaseGrantedMarker(receiptInfo)
	end)

	if not success then
		warn(`[AnalyticsService] Failed to send purchase marker: {problem}`)
	end
end

--[[
	Buffers marker batches the SDK could not deliver and retries them once.

	The SDK hands back the raw batch, which is the only form
	`RetryFailedMarkersAsync` accepts, so it is stored verbatim.
]]
function AnalyticsService._watchFailedMarkers(self: AnalyticsService)
	if not self.markers then
		return
	end

	self.markers:OnMarkersFailed(function(failedMarkers)
		if type(failedMarkers) ~= "table" then
			return
		end

		for _, marker in failedMarkers do
			if #self.bufferedFailedMarkers >= MAX_BUFFERED_FAILED_MARKERS then
				warn(`[AnalyticsService] Dropping failed markers; buffer is full at {MAX_BUFFERED_FAILED_MARKERS}.`)
				break
			end

			table.insert(self.bufferedFailedMarkers, marker)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(FAILED_MARKER_RETRY_DELAY)
			self:_retryFailedMarkers()
		end
	end)
end

function AnalyticsService._retryFailedMarkers(self: AnalyticsService)
	if #self.bufferedFailedMarkers == 0 then
		return
	end

	-- Swapped out before the yield so markers failing again are re-buffered by
	-- the callback rather than duplicated into the batch being retried.
	const pending = self.bufferedFailedMarkers
	self.bufferedFailedMarkers = {}

	const success, result = pcall(function()
		return self.markers:RetryFailedMarkersAsync(pending)
	end)

	if not success then
		warn(`[AnalyticsService] Failed marker retry errored: {result}`)
		return
	end

	if result ~= true then
		warn(`[AnalyticsService] Retry of {#pending} markers failed; they have been dropped.`)
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

	if not isRobloxAnalyticsAvailable then
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

--[[
	Throttles client-originated markers per player. Returns false when the
	marker should be dropped.
]]
function AnalyticsService._acceptClientMarker(self: AnalyticsService, player: Player): boolean
	const now = os.clock()
	const last = self.lastClientMarkerClockByPlayer[player]

	if last and now - last < CLIENT_MARKER_MIN_INTERVAL then
		return false
	end

	self.lastClientMarkerClockByPlayer[player] = now

	return true
end

--[[
	Resolves a client-supplied product key against the real product table.

	The client sends a key rather than a numeric id so an exploiter cannot
	fabricate revenue against an id we never sold.
]]
local function resolveProductKey(productKey: unknown): string?
	if typeof(productKey) ~= "string" then
		return nil
	end

	if productsByKey[productKey :: string] == nil then
		return nil
	end

	return productKey :: string
end

function AnalyticsService.logStoreOpened(self: AnalyticsService, player: Player, source: string): ()
	if not self:_acceptClientMarker(player) then
		return
	end

	-- Restores are reported but tagged, since the purchase overlay closes and
	-- reopens whatever menu was underneath it. Counting those as opens would
	-- make every purchase look like a second store visit.
	const resolvedSource = if source == Markers.storeSources.restore then Markers.storeSources.restore else Markers.storeSources.menu

	self:sendPlayerMarker(player, Markers.storeOpened, {
		source = resolvedSource,
	})
end

function AnalyticsService.logProductViewed(self: AnalyticsService, player: Player, productKey: string): ()
	const resolvedKey = resolveProductKey(productKey)

	if not resolvedKey then
		return
	end

	if not self:_acceptClientMarker(player) then
		return
	end

	self:sendPlayerMarker(player, Markers.productViewed, {
		offerId = resolvedKey,
		productId = productsByKey[resolvedKey].id,
	})
end

function AnalyticsService.logPurchaseStarted(self: AnalyticsService, player: Player, productKey: string): ()
	const resolvedKey = resolveProductKey(productKey)

	if not resolvedKey then
		return
	end

	if not self:_acceptClientMarker(player) then
		return
	end

	self:sendPlayerMarker(player, Markers.purchaseStarted, {
		offerId = resolvedKey,
		productId = productsByKey[resolvedKey].id,
	})
end

--[[
	Client-side purchase refusals and dismissals.

	Reason is validated against the shared table so the dashboard never has to
	cope with a free-text field.
]]
function AnalyticsService.logPurchaseDeclined(self: AnalyticsService, player: Player, productKey: string, reason: string): ()
	const resolvedKey = resolveProductKey(productKey)

	if not resolvedKey then
		return
	end

	if Markers.getFailureReason(reason) == nil then
		return
	end

	if not self:_acceptClientMarker(player) then
		return
	end

	self:sendPlayerMarker(player, Markers.purchaseFailed, {
		offerId = resolvedKey,
		productId = productsByKey[resolvedKey].id,
		reason = reason,
		-- Lets the dashboard exclude best-effort client signals from anything
		-- revenue-shaped without needing to know each reason individually.
		isClientReported = true,
	})
end

function AnalyticsService._startProgressionSnapshots(self: AnalyticsService)
	task.spawn(function()
		while true do
			task.wait(PROGRESSION_SNAPSHOT_INTERVAL)

			for _, player in Players:GetPlayers() do
				self:sendProgressionSnapshot(player)
			end
		end
	end)
end

--[[
	Emits the player's current economy and roster state.

	Periodic rather than event-driven: the value of `averageCarLevel` is as a
	time series per cohort, which is what makes it usable for balance work. A
	marker per merge would answer a different and much noisier question.
]]
function AnalyticsService.sendProgressionSnapshot(self: AnalyticsService, player: Player): ()
	const snapshot = self:_buildProgressionSnapshot(player)

	if not snapshot then
		return
	end

	self:sendPlayerMarker(player, Markers.playerProgression, snapshot)
end

function AnalyticsService._buildProgressionSnapshot(self: AnalyticsService, player: Player): { [string]: any }?
	-- Deliberately does not call `waitForData`: this runs on a timer and on
	-- PlayerRemoving, where yielding for a profile that may never load would
	-- stall the loop. A player without data simply produces no snapshot.
	const success, snapshot = pcall(function(): { [string]: any }?
		const runners = DataService:get(player, "runners")

		if runners == nil then
			return nil
		end

		const levels = RunnerUtils.sanitizeLevels(runners)

		local levelTotal = 0
		local regularCarCount = 0
		local maxCarLevel = 0
		local exclusiveCarCount = 0

		for _, level in levels do
			-- Exclusive cars share the `runners` array but start at id 1000, so
			-- a single one would drag a player's average from ~12 to ~500. They
			-- are counted separately instead.
			--
			-- Compares against the reserved band rather than only
			-- `isExclusive`, because an unregistered id in that band would
			-- otherwise silently poison the average we are trying to measure.
			if ExclusiveCars.isExclusive(level) or level >= ExclusiveCars.ID_BASE then
				exclusiveCarCount += 1
				continue
			end

			levelTotal += level
			regularCarCount += 1

			if level > maxCarLevel then
				maxCarLevel = level
			end
		end

		const upgrades = DataService:get(player, "upgrades") or {}
		const stats = DataService:get(player, "stats") or {}
		const joinClock = self.joinClockByPlayer[player]

		return {
			-- Gamebeast marker values must be flat: a primitive or a dictionary
			-- of primitives, never nested tables or arrays.
			averageCarLevel = if regularCarCount > 0 then levelTotal / regularCarCount else 0,
			maxCarLevel = maxCarLevel,
			runnerCount = regularCarCount,
			exclusiveCarCount = exclusiveCarCount,
			runnerSpawnLevel = DataService:get(player, "runnerSpawnLevel") or 0,
			runnerPurchases = DataService:get(player, "runnerPurchases") or 0,
			rebirths = DataService:get(player, "rebirths") or 0,
			cash = DataService:get(player, "cash") or 0,
			totalCashEarned = stats.totalCashEarned or 0,
			cashMultiplier = DataService:get(player, "cashMultiplier") or 1,
			selectedRoute = DataService:get(player, "selectedRoute") or 1,
			upgradeGates = upgrades.gates or 0,
			upgradeRunnerSpeed = upgrades.runnerSpeed or 0,
			upgradeCashBonus = upgrades.cashBonus or 0,
			extraGates = DataService:get(player, "extraGates") or 0,
			-- `stats.timePlayed` only advances at logout, so it is useless for a
			-- live session. Measured from join instead.
			sessionSeconds = if joinClock then math.floor(os.clock() - joinClock) else 0,
			tutorialFinished = DataService:get(player, TUTORIAL_FINISHED_PATH) == true,
		}
	end)

	if not success then
		warn(`[AnalyticsService] Failed to build progression snapshot for {player.Name}: {snapshot}`)
		return nil
	end

	return snapshot
end

--[[
	Values Gamebeast accepts for a marker.

	The SDK validates that a value is a primitive or a flat dictionary, and
	explicitly rejects arrays. `boolean` is included because several markers are
	simple presence flags (`tutorialStarted`, `tutorialFinished`).
]]
type MarkerValue = number | boolean | { [string]: any }

type AnalyticsService = typeof(AnalyticsService) & {
	networker: Networker.Server,
	markers: any,
	loggedStepsByPlayer: { [Player]: { [number]: boolean } },
	joinClockByPlayer: { [Player]: number },
	lastClientMarkerClockByPlayer: { [Player]: number },
	bufferedFailedMarkers: { { [string]: any } },
}

return AnalyticsService :: AnalyticsService
