local CashBar = require(script.Parent.CashBar)
local Navigator = require(script.Parent.Navigator)
local Purchasing = require(script.Parent.Purchasing)
local SideButtons = require(script.Parent.SideButtons)

return function()
	return {
		Navigator(),
		SideButtons(),

		Purchasing.Component(),
		CashBar.Component(),
	}
end
