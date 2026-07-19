--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local CodeServiceClient = require(ReplicatedStorage.Shared.Services.CodeService.CodeServiceClient)
local ShopContentFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopContentFrame)
local ShopFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopFrame)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function codesFrame()
	local resultText = Vide.source("")
	local resultTextColor3 = Vide.source(Color3.fromRGB(255, 255, 255))

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

		if success then
			resultTextColor3(Color3.fromRGB(92, 255, 92))
		else
			resultTextColor3(Color3.fromRGB(255, 64, 64))
		end

		resultText(message)

		task.delay(3, function()
			if resultText() == message then
				resultText("")
			end
		end)
	end

	return ShopFrame.Blue({
		Size = usePx.offset(1008, 184),

		TextLabel({
			Text = "Follow socials for codes!",
			Size = usePx.offset(500, 42),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.05),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(16, 16, 20) },
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			Font = Enum.Font.BuilderSansExtraBold,
		}),

		TextLabel({
			Text = resultText,
			Size = UDim2.fromOffset(200, 30),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.25),
			TextColor3 = resultTextColor3,
			Stroke = { Thickness = usePx(2), Color = Color3.fromRGB(16, 16, 20) },
			TextScaled = true,
			Font = Enum.Font.BuilderSansExtraBold,
		}),

		StudButton({
			Text = "Redeem",
			Position = UDim2.fromScale(0.825, 0.725),
			Size = UDim2.fromOffset(150, 45),
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			Colors = ButtonColors.Green,
			OnClick = redeem,
		} :: StudButton.StudButton),

		ShopFrame.Grey({
			Size = UDim2.fromScale(0.65, 0.35),
			Position = UDim2.fromScale(0.03, 0.9),
			AnchorPoint = Vector2.new(0, 1),

			Vide.create("TextBox", {
				Vide.action(function(instance)
					textBox = instance
				end),
				FocusLost = function(_, enterPressed)
					if enterPressed then
						redeem()
					end
				end,
				Font = Enum.Font.BuilderSansExtraBold,
				Size = UDim2.fromScale(0.97, 0.875),
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
