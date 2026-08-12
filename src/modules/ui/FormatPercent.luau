--[=[
	Formats a drop chance for display. Rare loot sits far below 1%, so the decimal count
	scales with the magnitude instead of being fixed, and trailing zeroes are trimmed so
	round chances stay short.

	@param percent number -- A chance already expressed out of 100.
	@return string
]=]
return function(percent: number): string
	if percent <= 0 then
		return "0%"
	end

	local formatted
	if percent >= 10 then
		formatted = string.format("%.1f", percent)
	elseif percent >= 1 then
		formatted = string.format("%.2f", percent)
	else
		formatted = string.format("%.3f", percent)
	end

	local trimmed = string.gsub(formatted, "0+$", "")
	trimmed = string.gsub(trimmed, "%.$", "")

	return trimmed .. "%"
end
