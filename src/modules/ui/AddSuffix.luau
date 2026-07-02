local SUFFIXES = { "st", "nd", "rd" }

return function(number: number)
	local lastTwo = number % 100

	-- 11th, 12th, 13th are exceptions to the st/nd/rd rule
	if lastTwo >= 10 and lastTwo <= 19 then
		return number .. "th"
	end

	return number .. (SUFFIXES[number % 10] or "th")
end
