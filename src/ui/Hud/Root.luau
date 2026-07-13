local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CashBar = require(script.Parent.CashBar)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local Navigator = require(script.Parent.Navigator)
local SideButtons = require(script.Parent.SideButtons)

return function()
	return {
		Navigator(),
		SideButtons(),

		Menu.setOpenedMenu("Settings"),

		CashBar.Component(),
	}
end
