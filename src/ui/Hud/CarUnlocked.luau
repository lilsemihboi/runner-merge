--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local CarIds = require(ReplicatedStorage.Shared.Modules.Items.CarIds)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local HudSlice = require(script.Parent.HudSlice)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local activeCarData: Vide.Source<{ number }> = Vide.source({})
local unlockSound = SoundService:WaitForChild("SFX"):WaitForChild("unlock")

local function CarRewardCard(carId: Vide.Source<number>, index: number)
	local titleScaleTarget = Vide.source(0)
	local titleScale = Vide.spring(titleScaleTarget, 0.35, 0.65)
	local scaleTarget = Vide.source(0)
	local scale = Vide.spring(scaleTarget, 0.35, 0.65)
	--
	task.delay((index - 1) * 0.12, function()
		unlockSound.PlaybackSpeed = 1 + (index - 1) * 0.2
		unlockSound:Play()

		titleScaleTarget(1)
		scaleTarget(1)
	end)

	return Frame({
		LayoutOrder = index,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.1125, 0.75),

		Vide.create("UIScale", {
			Scale = scale,
		}),

		-- Inner stroke
		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = Color3.fromRGB(255, 255, 255),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = usePx(6),
			Transparency = 0.5,
		}),

		-- Outer Stroke
		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			BorderStrokePosition = Enum.BorderStrokePosition.Outer,
			Color = Color3.fromRGB(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = usePx(6),
			Transparency = 0.5,
		}),

		Vide.create("UIPadding", {
			PaddingTop = usePx.udim(0, 6),
			PaddingBottom = usePx.udim(0, 6),
			PaddingLeft = usePx.udim(0, 6),
			PaddingRight = usePx.udim(0, 6),
		}),

		TextLabel({
			Size = usePx.offset(300, 60),
			Text = `Level {carId()}`,
			Position = UDim2.fromScale(0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Stroke = { Thickness = usePx(4) },
			ZIndex = 2,
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),

			Vide.create("UIScale", {
				Scale = titleScale,
			}),
		}),

		-- Car Image
		ImageLabel({
			Image = CarIds[carId()].imageId,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.45, 0.5),
			Size = usePx.offset(312, 312),
		}),
	})
end

local function Component()
	local prevMenu: string | nil
	local firstRun = true

	local barSizeTarget = Vide.source(UDim2.fromScale(0.05, 0.01))
	local barSize = Vide.spring(barSizeTarget, 0.45, 0.75)

	local bgTransparencyTarget = Vide.source(1)
	local bgTransparency = Vide.spring(bgTransparencyTarget, 0.3, 1)

	local BAR_FULL_SIZE = UDim2.fromScale(1.5, 0.347)
	Vide.effect(function()
		local isOpen = activeCarData() ~= nil

		if isOpen then
			prevMenu = Vide.untrack(Menu.openedMenu)
			Menu.setOpenedMenu(nil)
			HudSlice.showEverything(false)

			bgTransparencyTarget(0.55)
			barSizeTarget(BAR_FULL_SIZE)
		elseif not firstRun then
			if prevMenu ~= "OfflineRewards" then
				Menu.setOpenedMenu(prevMenu)
			end
			HudSlice.showEverything(true)

			bgTransparencyTarget(1)
			barSizeTarget(UDim2.new(BAR_FULL_SIZE.X.Scale, BAR_FULL_SIZE.X.Offset, 0, 0))
		end

		firstRun = false
	end)

	local inputConnection

	Vide.effect(function()
		local isOpen = activeCarData() ~= nil

		if isOpen and not inputConnection then
			inputConnection = UserInputService.InputBegan:Connect(function(_input, gameProcessed)
				if gameProcessed then
					return
				end

				activeCarData(nil) -- veya setCarData(nil)
			end)
		elseif not isOpen and inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end
	end)

	return Frame({
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = function()
			return activeCarData() ~= nil
		end,

		-- Unlocked a new car

		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = usePx.offset(528, 63),
			Position = UDim2.fromScale(0.5, 0.25),
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = `Unlocked a new car!`,
			Stroke = {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = usePx(3),
			},
			ZIndex = 2,
		}),

		-- Bar Frame
		Frame({
			Size = barSize,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 0.35,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			ZIndex = 2,

			Vide.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0.01, 0),
			}),

			Vide.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				Color = Color3.fromRGB(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = 0.03,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			}),

			Vide.indexes(function()
				return activeCarData() or {}
			end, CarRewardCard),
		}),

		-- Click anywhere to continue

		TextLabel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = usePx.offset(528, 63),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.95),
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Text = `Click anywhere to continue`,
			Stroke = {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = usePx(3),
			},
			ZIndex = 2,
		}),

		-- Background Effects

		Vide.create("CanvasGroup", {
			GroupColor3 = Color3.fromRGB(255, 255, 255),
			GroupTransparency = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = bgTransparency,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),

			-- Gives brightness
			Vide.create("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
				Rotation = -90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 0.113),
				}),
			}),

			ImageLabel({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				Image = "rbxassetid://138565845401354",
				ImageColor3 = Color3.fromRGB(0, 0, 0),
			}),
		}),
	})
end

local function setCarData(data: { number })
	activeCarData(data)
end

return {
	Component = Component,
	setCarData = setCarData,
}
