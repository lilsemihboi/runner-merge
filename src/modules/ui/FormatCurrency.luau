local Abbreviate = require(script.Parent.Abbreviate)

return function(amount: number, showDollarSign: boolean?)
	local prefix = if showDollarSign then "$" else ""

	-- Abbreviate large numbers (e.g. 10M+)
	if amount >= 10_000_000 then
		return prefix .. Abbreviate(amount, 5)
	end

	local str = tostring(math.round(amount))
	local sign = ""

	-- Handle negatives
	if str:sub(1, 1) == "-" then
		sign = "-"
		str = str:sub(2)
	end

	-- Insert thousands separators
	repeat
		local count
		str, count = str:gsub("^(%d+)(%d%d%d)", "%1,%2")
	until count == 0

	return sign .. prefix .. str
end
