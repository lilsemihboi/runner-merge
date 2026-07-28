--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Button = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Button)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local RouteServiceClient = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceClient)
local RouteServiceUtils = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceUtils)
local Sift = require(ReplicatedStorage.Packages.Sift)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

type RouteProps = {
	routeId: number,
	routeImage: string,
	routeRebirthRequirement: number,
} & Button.ButtonProps

local rebirths = getVideDataSource({ "rebirths" })
local selectedRoute = getVideDataSource({ "selectedRoute" })

local function routeIndex(props: RouteProps)
	return Button({
		LayoutOrder = props.runnerLevel,
		ImageTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		OnClick = function()
			RouteServiceClient:selectRoute(props.routeId)
		end,

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

		-- Route Name
		TextLabel({
			Size = usePx.offset(150, 30),
			Text = `Route {props.routeId}`,
			Position = UDim2.fromScale(0.5, 0.15),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Stroke = { Thickness = usePx(4) },
			ZIndex = 2,
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		}),

		-- Rebirth needed

		TextLabel({
			Size = usePx.offset(128, 32),
			Text = function()
				local hasEnoughRebirth = rebirths() >= props.routeRebirthRequirement

				if hasEnoughRebirth then
					return `Rebirth {props.routeRebirthRequirement}`
				else
					return `Rebirth <font color="rgb(255,30,18)">{props.routeRebirthRequirement}</font>`
				end
			end,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			RichText = true,
			Position = UDim2.fromScale(0.5, 0.85),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Stroke = { Thickness = usePx(4) },
			ZIndex = 2,
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		}),

		ImageLabel({
			Image = props.routeImage,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = usePx.offset(164, 164),

			ImageColor3 = function()
				local isOwned = rebirths() >= props.routeRebirthRequirement

				if isOwned then
					return Color3.fromRGB(255, 255, 255)
				else
					return Color3.fromRGB(0, 0, 0)
				end
			end,
		}),

		Frame({
			Size = usePx.udim2(1, 6, 0, 30),
			Position = UDim2.fromScale(0.5, -0.205),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.5,
			ZIndex = 0,
			Visible = function()
				local isSelected = selectedRoute() == props.routeId

				if isSelected then
					return true
				else
					return false
				end
			end,
			-- Inner stroke
			Vide.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = Color3.fromRGB(255, 255, 255),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = usePx(2),
				Transparency = 0.5,
			}),

			-- Outer Stroke
			Vide.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				BorderStrokePosition = Enum.BorderStrokePosition.Outer,
				Color = Color3.fromRGB(0, 0, 0),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = usePx(2),
				Transparency = 0.5,
			}),

			TextLabel({
				Text = "Selected",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Size = UDim2.fromScale(0.86, 0.86),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Font = Enum.Font.BuilderSansExtraBold,
				Stroke = {
					Thickness = usePx(2),
				},
			}),
		}),
	})
end

local function allRunners()
	return Sift.Array.map(RouteServiceUtils, function(routeInfo: { imageId: string, rebirthRequirement: number }, routeId: number)
		return routeIndex({
			routeId = routeId,
			routeImage = routeInfo.imageId,
			routeRebirthRequirement = routeInfo.rebirthRequirement,
		})
	end)
end

local function routesMenuContainer()
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
			PaddingTop = usePx.udim(0, 60),
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
	menuId = "Routes",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "Routes",
			Title = "Routes",
			Scale = 0.90,

			routesMenuContainer(),
		})
	end,
}
