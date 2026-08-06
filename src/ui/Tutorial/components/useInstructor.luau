const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Vide = require(ReplicatedStorage.Packages.Vide)
const Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
const TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
const usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

-- One above UINavigator's DEFAULT_DISPLAY_ORDER, so the instructor draws over
-- the dimming stroke. ZIndex cannot do this: the two live in separate
-- ScreenGuis, and ZIndex only orders siblings within a single ScreenGui, so
-- stacking between them is decided purely by DisplayOrder.
const DISPLAY_ORDER = 1_000_001

return function(instructorText: Vide.Source<string>)
	const isInstructorVisible = Vide.derive(function()
		if instructorText() ~= "" then
			return true
		end
		return false
	end)

	const screenGui = Vide.create("ScreenGui", {
		Name = "TutorialInstructor",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ClipToDeviceSafeArea = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = DISPLAY_ORDER,

		Frame({
			Visible = isInstructorVisible,
			ZIndex = 2147483647,
			Size = usePx.udim2(0.8, 0, 0, 80),
			Position = UDim2.fromScale(0.5, 0.17),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.25,

			Vide.create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.33, 0.5),
					NumberSequenceKeypoint.new(0.66, 0.5),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),

			TextLabel({
				Size = UDim2.fromScale(0.85, 0.85),
				Font = Enum.Font.BuilderSansExtraBold,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				RichText = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Stroke = {
					Thickness = usePx(2),
				},
				TextWrapped = false,
				Text = instructorText,
			}),
		}),
	})

	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Vide.cleanup(function()
		screenGui:Destroy()
	end)

	return screenGui
end
