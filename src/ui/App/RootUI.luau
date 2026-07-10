local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	})
end
