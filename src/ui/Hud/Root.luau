local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
return function()
	return {
		StudButton(),
	}
end
