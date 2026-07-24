local CashBar = require(script.Parent.CashBar)
local Navigator = require(script.Parent.Navigator)
local Notice = require(script.Parent.Notice)
local Purchasing = require(script.Parent.Purchasing)
local SideButtons = require(script.Parent.SideButtons)

return function()
	return {
		Navigator(),
		SideButtons(),

		Notice.Component(),
		Purchasing.Component(),
		CashBar.Component(),
	}
end
