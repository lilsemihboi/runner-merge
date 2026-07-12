local Utils = {}

function Utils.getMinOfflineSeconds()
	return 900
end

function Utils.getMaxOfflineSeconds()
	return 43200 -- 12 hours
end

function Utils.getEligibleOfflineSeconds(elapsedTime: number?): number
	local seconds = math.max(math.floor(elapsedTime or 0), 0)

	if seconds < Utils.getMinOfflineSeconds() then
		return 0
	end

	return (math.min(seconds, Utils.getMaxOfflineSeconds()))
end

return Utils
