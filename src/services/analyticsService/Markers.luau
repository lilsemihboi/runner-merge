--!strict

--[[
	Shared Gamebeast marker vocabulary.

	Marker names and reason codes are the dashboard's schema, not internal
	identifiers. Renaming a published marker splits its history into two
	unrelated series on the dashboard, so treat existing entries as frozen once
	they have shipped.

	Both halves of the game read from this table, so a client-emitted marker and
	its server-emitted counterpart can never drift apart -- the same reason
	`OnboardingFunnel` is shared rather than duplicated.
]]

const Markers = {}

-- Monetization
Markers.storeOpened = "storeOpened"
Markers.productViewed = "productViewed"
Markers.purchaseStarted = "purchaseStarted"
Markers.purchaseSuccess = "purchaseSuccess"
Markers.purchaseFailed = "purchaseFailed"

-- Tutorial
Markers.tutorialStarted = "tutorialStarted"
Markers.tutorialStep = "tutorialStep"
Markers.tutorialFinished = "tutorialFinished"

-- Progression
Markers.runnerPurchased = "runnerPurchased"
Markers.runnerMerged = "runnerMerged"
Markers.playerProgression = "playerProgression"

--[[
	`reason` values for `purchaseFailed`.

	Server reasons are authoritative: they describe a receipt that Roblox
	delivered and the game refused. Client reasons describe a purchase the game
	refused before ever prompting, or a prompt the player dismissed, and are
	best-effort only.

	Revenue must never be derived from client reasons. `declined` in particular
	rides on `PromptProductPurchaseFinished`, which the Gamebeast SDK itself
	declines to trust ("Too many false positives", PurchaseAnalytics.luau).
]]
Markers.failureReasons = table.freeze({
	-- Server: receipt received, grant refused.
	noPlayer = "noPlayer",
	dataLoadFailed = "dataLoadFailed",
	unknownProduct = "unknownProduct",
	alreadyOwned = "alreadyOwned",
	cooldown = "cooldown",
	disabled = "disabled",
	noCallback = "noCallback",
	callbackError = "callbackError",
	-- Server: callback deliberately soft-failed, receipt still granted.
	grantRejected = "grantRejected",

	-- Client: refused before prompting.
	soldOut = "soldOut",
	policyBlocked = "policyBlocked",
	-- Client: prompt shown, player did not buy.
	declined = "declined",
})

--[[
	Returns the reason code when it is one we defined, otherwise nil.

	Used to validate client-supplied reasons so the dashboard never has to cope
	with a free-text field.
]]
function Markers.getFailureReason(reason: unknown): string?
	if typeof(reason) ~= "string" then
		return nil
	end

	return (Markers.failureReasons :: { [string]: string })[reason :: string]
end

--[[
	`source` values for `storeOpened`, so the dashboard can separate players who
	deliberately opened the shop from UI state being restored underneath them.
]]
Markers.storeSources = table.freeze({
	menu = "menu",
	restore = "restore",
})

return table.freeze(Markers)
