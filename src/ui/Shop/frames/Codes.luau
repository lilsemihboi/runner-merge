--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local CodeServiceClient = require(ReplicatedStorage.Shared.Services.CodeService.CodeServiceClient)
local ErrorMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.ErrorMessage)
local ShopContentFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopContentFrame)
local ShopFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopFrame)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function codesFrame()
	local textBox

	local function redeem()
		if not textBox then
			return
		end

		local code = textBox.Text
		if code == "" then
			return
		end

		local success, message = CodeServiceClient:redeem(code)

		if not success then
			ErrorMessage.add(message)
		end
	end

	return ShopFrame.Blue({
		Size = usePx.offset(1008, 184),

		TextLabel({
			Text = "Follow socials for codes!",
			Size = usePx.offset(800, 42),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.05),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(16, 16, 20) },
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			Font = Enum.Font.BuilderSansExtraBold,
		}),

		StudButton({
			Text = "Redeem",
			Position = usePx.udim2(0.825, 0, 0.63, 0),
			Size = usePx.udim2(0, 175, 0.35, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			Colors = ButtonColors.Green,
			OnClick = redeem,
			ZIndex = 2,
		} :: StudButton.StudButton),

		ShopFrame.Grey({
			Size = usePx.udim2(0.675, 0, 0.35, 0),
			Position = usePx.udim2(0.03, 0, 0.8, 0),
			AnchorPoint = Vector2.new(0, 1),

			Vide.create("TextBox", {
				Vide.action(function(instance)
					textBox = instance
				end),
				Font = Enum.Font.BuilderSansExtraBold,
				Size = usePx.udim2(0.95, 0, 0.85, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				PlaceholderText = "Enter Code Here",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				ClearTextOnFocus = true,
				TextScaled = true,
				TextStrokeTransparency = 0,
				PlaceholderColor3 = Color3.fromRGB(216, 216, 219),
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			}),
		}),
	})
end

return function()
	return ShopContentFrame({
		Text = "~Codes~",
		LayoutOrder = 5,
		Padding = 5,

		codesFrame(),
	})
end
