return function(totalSeconds: number)
	local seconds = math.max(0, totalSeconds)

	local days = seconds // 86400
	local hours = seconds % 86400 // 3600
	local minutes = seconds % 3600 // 60
	local secs = seconds % 60

	local result = ""

	if days > 0 then
		result ..= ("%*d "):format(days)
	end
	if hours > 0 then
		result ..= ("%*h "):format(hours)
	end
	if minutes > 0 then
		result ..= ("%*m "):format(minutes)
	end

	-- Only show seconds if we're under an hour
	if secs > 0 and days == 0 and hours == 0 then
		return result .. `{secs}s`
	end

	return result:sub(1, -2)
end
