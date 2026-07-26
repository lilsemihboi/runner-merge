local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local HudSlice = require(script.Parent.HudSlice)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local SoundServiceClient = require(ReplicatedStorage.Shared.Services.SoundService.SoundServiceClient)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function carText()
	return TextLabel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.1),
		Text = "YOUR CARS KEEP EARNING WHILE YOU ARE OFFLINE",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		Gradient = {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 30, 86)),
				ColorSequenceKeypoint.new(0.2, Color3.fromRGB(161, 30, 255)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(30, 180, 255)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(49, 255, 30)),
				ColorSequenceKeypoint.new(0.8, Color3.fromRGB(255, 255, 30)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 143, 30)),
			}),
			Rotation = 0,
		},
		Stroke = {
			Color = Color3.fromRGB(0, 0, 0),
			Thickness = usePx(3),
		},
	})
end

local function allTextLabels()
	local children = {}
	for _ = 1, 10, 1 do
		table.insert(children, carText())
	end

	return children
end

local function component()
	local isMenuOpen = Vide.source(GuiService.MenuIsOpen)

	local prevMenu: string | nil
	local firstRun = true

	Vide.effect(function()
		local isOpen = isMenuOpen()

		if isOpen then
			prevMenu = Vide.untrack(Menu.openedMenu)
			Menu.setOpenedMenu(nil)
			HudSlice.showEverything(false)
		elseif not firstRun then
			if prevMenu ~= "OfflineRewards" then
				Menu.setOpenedMenu(prevMenu)
			end
			HudSlice.showEverything(true)
		end

		firstRun = false
	end)

	GuiService.MenuOpened:Connect(function()
		SoundServiceClient:play("notification")
		isMenuOpen(true)
	end)

	GuiService.MenuClosed:Connect(function()
		isMenuOpen(false)
	end)

	return Frame({
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Visible = isMenuOpen,

		Vide.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 0),
		}),

		table.unpack(allTextLabels()),
	})
end

return {
	Component = component,
}
