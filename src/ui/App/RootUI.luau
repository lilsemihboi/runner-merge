local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CratesScreen = require(ReplicatedStorage.Shared.UI.Crates.CratesScreen)
local ErrorMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.ErrorMessage)
local NotificationMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.NotificationMessage)
local Notifications = require(ReplicatedStorage.Shared.UI.App.Components.Notifications)
local Sift = require(ReplicatedStorage.Packages.Sift)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local e = Vide.create

local hasBuiltRegistry = false
local capturedRoots = {}

local function captureRoots()
	if hasBuiltRegistry then
		return
	end
	hasBuiltRegistry = true

	for _, module in ReplicatedStorage.Shared.UI:GetDescendants() do
		if module:IsA("ModuleScript") and module.Name:lower():find("root") and module ~= script and not (module.Name:find(".story")) then
			table.insert(capturedRoots, require(module :: any) :: any)
		end
	end
end

return function()
	captureRoots()
	usePx.usePx()

	return e("ScreenGui", {
		Name = "Root",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ClipToDeviceSafeArea = false,

		Sift.Array.map(capturedRoots, function(root)
			return root()
		end),

		ErrorMessage.Component(),
		NotificationMessage.Component(),
		Notifications.Screen(),
		CratesScreen.Component(),
	})
end
