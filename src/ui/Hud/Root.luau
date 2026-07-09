local CashBar = require(script.Parent.CashBar)
local Navigator = require(script.Parent.Navigator)
local SideButtons = require(script.Parent.SideButtons)

return function()
	return {
		Navigator(),
		SideButtons(),
		CashBar(),
	}
end
