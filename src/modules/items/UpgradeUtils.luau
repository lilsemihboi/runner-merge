local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local UpgradeUtils = {}

--[[
    Utilities to calculate cost of upgrades
]]

type UpgradeId = keyof<typeof(_DataTemplate.upgrades)>

local UPGRADE_BASE_COSTS: { [UpgradeId]: number } = {
	gates = 25,
	runnerSpeed = 50,
	cashBonus = 250,
}

local UPGRADE_GROWTH: { [UpgradeId]: number } = {
	gates = 1.45,
	runnerSpeed = 1.55,
	cashBonus = 1.7,
}

UpgradeUtils.levelCaps = {
	gates = 10,
	runnerSpeed = 10,
	cashBonus = 10,
}

function UpgradeUtils.calculateUpgradeCost(upgradeId: UpgradeId, upgradeLevel: number): number
	local level = math.max(0, math.floor(upgradeLevel))

	local function roundToTens(value: number): number
		return math.floor((value + 5) / 10) * 10
	end

	if level == 1 and upgradeId == "gates" then
		return 0
	end

	local baseCost = UPGRADE_BASE_COSTS[upgradeId]
	local growth = UPGRADE_GROWTH[upgradeId]

	return roundToTens(baseCost * (growth ^ level))
end

return UpgradeUtils
