--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Button)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local InventoryServiceClient = require(ReplicatedStorage.Shared.Services.InventoryService.InventoryServiceClient)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)
local Vide = require(ReplicatedStorage.Packages.Vide)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local inventory = getVideDataSource({ "inventory" })
local selectedTrail = getVideDataSource({ "selectedTrail" })

local ownedTrails = Vide.derive(function()
	local quantities: { [number]: number } = {}

	for _, trailId in inventory() or {} do
		if Trails[trailId] then
			quantities[trailId] = (quantities[trailId] or 0) + 1
		end
	end

	return quantities
end)

local function trailButton(trailId: number, quantity: () -> number)
	local trailInfo = Trails[trailId]

	return Button({
		LayoutOrder = trailId,
		ImageTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		OnClick = function()
			local nextTrail = if selectedTrail() == trailId then nil else trailId
			InventoryServiceClient:selectTrail(nextTrail)
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

		-- Outer stroke
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
			Size = usePx.offset(150, 30),
			Text = trailInfo.trailName,
			Position = UDim2.fromScale(0.5, 0.15),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Stroke = { Thickness = usePx(4) },
			ZIndex = 2,
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		}),

		TextLabel({
			Size = usePx.offset(96, 52),
			Text = function()
				return `x{quantity()}`
			end,
			Position = UDim2.fromScale(1, -0.05),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Stroke = { Thickness = usePx(3) },
			ZIndex = 2,
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		}),

		Frame({
			Name = "Preview",
			Size = usePx.offset(154, 62),
			Position = UDim2.fromScale(0.5, 0.51),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 1,

			Vide.create("UIGradient", {
				Name = "Gradient",
				Color = trailInfo.trailColorSequence,
			}),
		}),

		TextLabel({
			Size = usePx.offset(128, 32),
			Text = string.format("x%.2f Cash", trailInfo.trailMultiplier),
			TextColor3 = Color3.fromRGB(159, 255, 80),
			Position = UDim2.fromScale(0.5, 0.85),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Stroke = { Thickness = usePx(4) },
			ZIndex = 2,
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
		}),

		Frame({
			Size = usePx.udim2(1, 6, 0, 30),
			Position = UDim2.fromScale(0.5, -0.205),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.5,
			ZIndex = 0,
			Visible = function()
				return selectedTrail() == trailId
			end,

			Vide.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = Color3.fromRGB(255, 255, 255),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = usePx(2),
				Transparency = 0.5,
			}),

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

local function inventoryMenuContainer()
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

		Vide.indexes(ownedTrails, function(quantity, trailId)
			return trailButton(trailId, quantity)
		end),
	})
end

return {
	menuId = "Inventory",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "Inventory",
			Title = "Inventory",
			Scale = 0.90,

			inventoryMenuContainer(),
		})
	end,
}
