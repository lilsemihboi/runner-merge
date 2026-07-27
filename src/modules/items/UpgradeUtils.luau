local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local GetDataSource = require(ReplicatedStorage.Shared.Modules.Ui.Sources.GetDataSource)
local RouteServiceUtils = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceUtils)
local _DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local UpgradeUtils = {}

--[[
    Utilities to calculate cost of upgrades
]]

type UpgradeId = keyof<typeof(_DataTemplate.upgrades)>

local UPGRADE_BASE_COSTS: { [UpgradeId]: number } = {
	gates = 50,
	runnerSpeed = 100,
	cashBonus = 500,
}

local UPGRADE_GROWTH: { [UpgradeId]: number } = {
	gates = 2.5,
	runnerSpeed = 1.7,
	cashBonus = 1.85,
}

UpgradeUtils.levelCaps = {
	gates = Charm.atom(10),
	runnerSpeed = Charm.atom(10),
	cashBonus = Charm.atom(10),
} :: { [UpgradeId]: Charm.Atom<number> }

function UpgradeUtils.updateLevelCaps()
	local selectedRoute = GetDataSource({ "selectedRoute" })

	local function updateLevelCapForGate(routeId: number)
		local routeGateCap = RouteServiceUtils[routeId].gateCap
		UpgradeUtils.levelCaps.gates(routeGateCap)
	end

	updateLevelCapForGate(selectedRoute())

	Charm.subscribe(selectedRoute, function(state)
		updateLevelCapForGate(state)
	end)
end

function UpgradeUtils.calculateUpgradeCost(upgradeId: UpgradeId, upgradeLevel: number): number
	local level = math.max(0, math.floor(upgradeLevel))

	local function roundToTens(value: number): number
		return math.floor((value + 5) / 10) * 10
	end

	if upgradeId == "gates" then
		if level == 1 then
			return 0
		elseif level == 2 then
			return 50
		end
		return roundToTens(5000 * (2.5 ^ (level - 3)))
	end

	local baseCost = UPGRADE_BASE_COSTS[upgradeId]
	local growth = UPGRADE_GROWTH[upgradeId]

	return roundToTens(baseCost * (growth ^ level))
end

return UpgradeUtils
