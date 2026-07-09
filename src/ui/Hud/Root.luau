local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)

return function()
	return {
		StudButton({
			Size = UDim2.fromScale(0.5, 0.35),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Colors = ButtonColors.Green,
			Text = "LARP",
		} :: StudButton.StudButton),
	}
end
