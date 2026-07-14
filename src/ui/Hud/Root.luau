local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CashBar = require(script.Parent.CashBar)
local Navigator = require(script.Parent.Navigator)
local SideButtons = require(script.Parent.SideButtons)

return function()
	return {
		Navigator(),
		SideButtons(),
		CashBar.Component(),
	}
end
