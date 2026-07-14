--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CarIds = require(ReplicatedStorage.Shared.Modules.Items.CarIds)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local Sift = require(ReplicatedStorage.Packages.Sift)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function topInfoText()
	local ownedCars = getVideDataSource({ "index" })

	return TextLabel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = function()
			return `{Sift.Dictionary.count(ownedCars())}/{#CarIds}`
		end,
		Position = usePx.udim2(0, 730, 0, 46),
		Size = usePx.offset(100, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Stroke = {
			Thickness = usePx(4),
		},
		DropShadow = {
			Transparency = 0,

			Vide.create("UIStroke", {
				Thickness = usePx(4),
			}),
		},
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		ZIndex = 99,
	})
end

return {
	menuId = "Index",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "Index",
			Title = "Index",
			Scale = 0.90,

			topInfoText(),
		})
	end,
}
