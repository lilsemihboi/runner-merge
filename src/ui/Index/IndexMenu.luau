--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local Button = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Button)
local CarIds = require(ReplicatedStorage.Shared.Modules.Items.CarIds)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)
local Sift = require(ReplicatedStorage.Packages.Sift)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

type IndexProps = {
	runnerLevel: number,
	runnerName: string,
	runnerImage: string,
} & Button.ButtonProps

local ownedCars = getVideDataSource({ "index" })

local function runnerIndex(props: IndexProps)
	return Button({
		LayoutOrder = props.runnerLevel,
		ImageTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,

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

		-- Car Name
		TextLabel({
			Size = usePx.offset(150, 30),
			Text = function()
				local isOwned = ownedCars()[tostring(props.runnerLevel)]

				if isOwned then
					return props.runnerName
				else
					return "???"
				end
			end,
			Position = UDim2.fromScale(0.5, 0.15),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Stroke = { Thickness = usePx(4) },
			ZIndex = 2,
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		}),

		-- Car Income Per Lap

		TextLabel({
			Size = usePx.offset(128, 32),
			Text = function()
				local isOwned = ownedCars()[tostring(props.runnerLevel)]

				if isOwned then
					return `${Abbreviate(RunnerUtils.getRunnerIncomePerLap(props.runnerLevel))}`
				else
					return "???"
				end
			end,
			TextColor3 = function()
				local isOwned = ownedCars()[tostring(props.runnerLevel)]

				if isOwned then
					return Color3.fromRGB(159, 255, 80)
				else
					return Color3.fromRGB(255, 255, 255)
				end
			end,
			Position = UDim2.fromScale(0.5, 0.85),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Stroke = { Thickness = usePx(4) },
			ZIndex = 2,
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		}),

		-- Car Image
		ImageLabel({
			Image = props.runnerImage,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.45, 0.45),
			Size = usePx.offset(178, 178),
			ImageColor3 = function()
				local isOwned = ownedCars()[tostring(props.runnerLevel)]

				if isOwned then
					return Color3.fromRGB(255, 255, 255)
				else
					return Color3.fromRGB(0, 0, 0)
				end
			end,
		}),
	})
end

local function allRunners()
	return Sift.Array.map(CarIds, function(carInfo: { imageId: string, name: string }, carLevel: number)
		return runnerIndex({
			runnerLevel = carLevel,
			runnerName = carInfo.name,
			runnerImage = carInfo.imageId,
		})
	end)
end

local function topInfoText()
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
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		ZIndex = 99,
	})
end

local function indexMenuContainer()
	return Vide.create("ScrollingFrame", {
		Size = usePx.offset(1008 * 0.9, 686 * 0.9),
		Position = usePx.udim2(0, 0, 0, 116 * 0.9),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,

		Vide.create("UIPadding", {
			PaddingTop = usePx.udim(0, 25),
			PaddingBottom = usePx.udim(0, 25),
			PaddingLeft = usePx.udim(0, 18),
			PaddingRight = usePx.udim(0, 18),
		}),

		Vide.create("UIGridLayout", {
			CellSize = usePx.offset(190, 190),
			CellPadding = usePx.offset(30, 28),
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		allRunners(),
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
			indexMenuContainer(),
		})
	end,
}
