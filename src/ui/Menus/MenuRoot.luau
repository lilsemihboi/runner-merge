--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local Vide = require(ReplicatedStorage.Packages.Vide)

local hasBuiltRegistry = false
local alwaysMountedMenus: { any } = {}
local menuComponents: { [any]: any } = {}

local function registerMenu(module: Instance)
	if not module:IsA("ModuleScript") or (not module.Name:find("Menu") or module == script or module.Name == "Menu") then
		return
	end

	local menu = require(module :: any) :: any
	local menuId = if type(menu) ~= "table" then nil else menu.menuId

	if type(menu) ~= "table" or not menuId or not menu.Component then
		return
	end

	if menu.alwaysMounted then
		table.insert(alwaysMountedMenus, menu.Component())
		return
	end

	menuComponents[menuId] = function()
		return menu.Component(), 1
	end
end

return function()
	if not hasBuiltRegistry then
		hasBuiltRegistry = true
		for _, module in ReplicatedStorage.Shared.UI:GetDescendants() do
			registerMenu(module)
		end
	end

	local openedMenu = Vide.derive(function(): any
		return Menu.openedMenu()
	end)

	return {
		alwaysMountedMenus,
		Vide.switch(openedMenu)(menuComponents),
	}
end
