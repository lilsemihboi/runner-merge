local CashBar = require(script.Parent.CashBar)
local Navigator = require(script.Parent.Navigator)

return function()
	return {
		Navigator(),
		CashBar(),
	}
end
