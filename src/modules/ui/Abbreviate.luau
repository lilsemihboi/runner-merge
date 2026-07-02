local Suffixes = require(script.Parent.Suffixes)

return function(amount: number, precision: number?)
	local sign = ""
	local maxDigits = precision or 3

	if amount < 0 then
		amount = math.abs(amount)
		sign = "-"
	end

	local formatted = ("%.0f"):format(amount)
	local digitCount = #formatted

	-- No abbreviation needed for numbers 999 and under
	if digitCount <= 3 then
		return sign .. formatted
	end

	local suffix = Suffixes[math.ceil(digitCount / 3)]
	local leadingDigits = (digitCount - 1) % 3 + 1

	-- Fall back to scientific-style suffix if number exceeds suffix table (e.g. "e15")
	if not suffix then
		suffix = "e" .. math.ceil((digitCount - 3) / 3) * 3
	end

	local result = formatted:sub(1, leadingDigits)

	if leadingDigits < maxDigits then
		result ..= "." .. formatted:sub(leadingDigits + 1, maxDigits)
	end

	return sign .. result .. suffix
end
