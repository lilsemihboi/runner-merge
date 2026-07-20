--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local SoundServiceClient = require(ReplicatedStorage.Shared.Services.SoundService.SoundServiceClient)
local Vide = require(ReplicatedStorage.Packages.Vide)

local SPRING_PERIOD = 0.35
local SPRING_DAMPING = 0.55

local isPurchaseShowing = Vide.source(false)

local function displayPurchasing(displaying: boolean)
	if displaying then
		SoundServiceClient:play("promptPurchase")
	end

	isPurchaseShowing(displaying)
end

local function component()
	local Camera = workspace.CurrentCamera

	local backgroundTarget = Vide.derive(function()
		return isPurchaseShowing() and 0.75 or 1
	end)

	local imageTarget = Vide.derive(function()
		return isPurchaseShowing() and 0.25 or 1
	end)

	local fovTarget = Vide.derive(function()
		return isPurchaseShowing() and 60 or 70
	end)

	local backgroundTransparency = Vide.spring(backgroundTarget, SPRING_PERIOD, SPRING_DAMPING)
	local imageTransparency = Vide.spring(imageTarget, SPRING_PERIOD, SPRING_DAMPING)
	local cameraFov = Vide.spring(fovTarget, SPRING_PERIOD, SPRING_DAMPING)

	local rotation = Vide.source(0)

	Vide.effect(function()
		Camera.FieldOfView = cameraFov()
	end)

	Vide.effect(function()
		if not isPurchaseShowing() then
			return
		end

		local conn = RunService.RenderStepped:Connect(function(dt)
			rotation((rotation() + dt * 100) % 360) -- 100 derece/saniye
		end)

		Vide.cleanup(function()
			conn:Disconnect()
		end)
	end)

	local prevMenu: string | nil
	Vide.effect(function()
		local isShowing = isPurchaseShowing()
		print("updated")
		if isShowing then
			prevMenu = Vide.untrack(Menu.openedMenu)
			Menu.setOpenedMenu(nil)
		else
			Menu.setOpenedMenu(prevMenu)
		end
	end)

	return Frame({
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),

		Frame({
			BackgroundTransparency = backgroundTransparency,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 2147483645,
		}),

		ImageLabel({
			BackgroundTransparency = 1,
			Image = "rbxassetid://96832187093620",
			ImageTransparency = imageTransparency,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.091, 0.223),
			Rotation = rotation,
			ZIndex = 2147483646,

			Vide.create("UIAspectRatioConstraint", {
				AspectRatio = 1,
				DominantAxis = Enum.DominantAxis.Width,
				AspectType = Enum.AspectType.FitWithinMaxSize,
			}),
		}),

		ImageLabel({
			BackgroundTransparency = 1,
			Image = "rbxassetid://140118163349558",
			ImageTransparency = imageTransparency,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2147483646,

			Vide.create("UIGradient", {
				Rotation = rotation,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 125, 125)),
					ColorSequenceKeypoint.new(0.166, Color3.fromRGB(255, 175, 100)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 127)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(85, 255, 127)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(85, 170, 255)),
					ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 125, 255)),
					ColorSequenceKeypoint.new(0.99, Color3.fromRGB(255, 118, 240)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 118, 240)),
				}),
			}),
		}),
	})
end

return {
	DisplayPurchasing = displayPurchasing,
	Component = component,
}
