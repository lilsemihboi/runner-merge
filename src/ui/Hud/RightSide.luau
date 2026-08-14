--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Button)
local CarIds = require(ReplicatedStorage.Shared.Modules.Items.CarIds)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local HudSlice = require(ReplicatedStorage.Shared.UI.Hud.HudSlice)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local RemoveKeys = require(ReplicatedStorage.Shared.Modules.Utils.RemoveKeys)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
const VideCharm = require(ReplicatedStorage.Packages.VideCharm)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)
const TutorialSlice = require(ReplicatedStorage.Shared.UI.Tutorial.TutorialSlice)

type ProductIndex = {
	title: string,
	image: string,
} & Button.ButtonProps

local CUSTOM_KEYS = {
	"title",
	"image",
}

local function productIndex(props: ProductIndex)
	local safeProps = RemoveKeys(props, CUSTOM_KEYS)
	return Button({
		Size = usePx.offset(140, 144),
		BackgroundTransparency = 1,
		OnClick = props.OnClick,
		Visible = props.Visible,
		LayoutOrder = props.LayoutOrder or 1,
		--Title
		TextLabel({
			Text = props.title,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.95, 0.35),
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			TextXAlignment = Enum.TextXAlignment.Center,
			Stroke = {
				Color = Color3.fromRGB(0, 85, 0),
				Thickness = usePx(5),
			},
			Gradient = {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(103, 255, 8)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(179, 255, 0)),
				}),
				Rotation = 90,
			},
			ZIndex = 5,
		}),

		Vide.create("UIAspectRatioConstraint", {
			AspectRatio = 1,
			AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}),

		-- Sunburst (3x)
		ImageLabel({
			Size = UDim2.fromScale(0.961, 0.961),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Image = "rbxassetid://84791833149232",
		}),

		ImageLabel({
			Size = UDim2.fromScale(0.961, 0.961),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Image = "rbxassetid://84791833149232",
		}),

		ImageLabel({
			Size = UDim2.fromScale(0.961, 0.961),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Image = "rbxassetid://84791833149232",
		}),

		-- Main ImageLabel

		ImageLabel({
			Size = UDim2.fromScale(0.961, 0.961),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.45, 0.45),
			Image = props.image or nil,
			ZIndex = 2,
			Rotation = 5,
		}),

		table.unpack(safeProps),
	})
end

return function()
	local isGroupRewardClaimed = getVideDataSource({ "isGroupRewardClaimed" })
	local ownsStarterPack = Vide.source(MonetizationServiceClient:ownsOneTimePurchase(Products.starterPack))
	local starterPackPrice = Vide.source(MonetizationServiceClient:getProductCostString(Products.starterPack))

	const isTutorialFinished = VideCharm.useAtom(TutorialSlice.states.isTutorialFinished)
	const localTutorialStage = VideCharm.useAtom(TutorialSlice.states.localTutorialStage)

	MonetizationServiceClient:getProductInfoChangedSignal(Products.starterPack):Connect(function()
		ownsStarterPack(MonetizationServiceClient:ownsOneTimePurchase(Products.starterPack))
		starterPackPrice(MonetizationServiceClient:getProductCostString(Products.starterPack))
	end)

	local sidebarPositionTarget = Vide.derive(function()
		if Menu.openedMenu() == nil then
			-- Ekranda
			return usePx.udim2(0.9, 0, 500 / 1080, 0)()
		else
			return UDim2.fromScale(1, 500 / 1080)
		end
	end)
	local sidebarPosition = Vide.spring(sidebarPositionTarget, 0.35, 0.8)

	return Frame({
		Size = usePx.offset(156, 412),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = sidebarPosition,
		BackgroundTransparency = 1,
		Visible = function()
			if HudSlice.showEverything() and (isTutorialFinished() or localTutorialStage() >= 10) then
				return true
			else
				return false
			end
		end,

		Vide.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.2, 0),
		}),

		productIndex({
			title = "GROUP",
			image = CarIds[4].imageId,

			Visible = function()
				return not isGroupRewardClaimed()
			end,
			LayoutOrder = 1,

			TextLabel({
				Text = "FREE",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.678, 0.037),
				Rotation = 13,
				Size = UDim2.fromScale(1.464, 0.315),
				TextScaled = true,
				ZIndex = 5,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				TextXAlignment = Enum.TextXAlignment.Center,
				Stroke = {
					Color = Color3.fromRGB(83, 9, 9),
					Thickness = usePx(5),
				},
				Gradient = {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 38, 136)),
						ColorSequenceKeypoint.new(0.133, Color3.fromRGB(207, 61, 255)),
						ColorSequenceKeypoint.new(0.273, Color3.fromRGB(10, 222, 255)),
						ColorSequenceKeypoint.new(0.458, Color3.fromRGB(21, 255, 17)),
						ColorSequenceKeypoint.new(0.671, Color3.fromRGB(255, 255, 29)),
						ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 157, 19)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 15, 15)),
					}),
					Rotation = 54,
				},
			}),

			OnClick = function()
				Menu.setOpenedMenu("GroupRewards")
			end,
		}),
		productIndex({
			title = "STARTER PACK",
			image = "rbxassetid://90845757723339",
			LayoutOrder = 2,

			Visible = function()
				return not ownsStarterPack()
			end,

			TextLabel({
				Text = starterPackPrice,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.678, 0.037),
				Rotation = 13,
				Size = UDim2.fromScale(1.464, 0.315),
				TextScaled = true,
				ZIndex = 5,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				TextXAlignment = Enum.TextXAlignment.Center,
				Stroke = {
					Color = Color3.fromRGB(85, 71, 0),
					Thickness = usePx(5),
				},
				Gradient = {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 179, 0)),
						ColorSequenceKeypoint.new(0.325, Color3.fromRGB(255, 238, 3)),
						ColorSequenceKeypoint.new(0.529, Color3.fromRGB(255, 179, 0)),
						ColorSequenceKeypoint.new(0.696, Color3.fromRGB(255, 238, 3)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 179, 0)),
					}),
					Rotation = 8,
				},
			}),

			OnClick = function()
				MonetizationServiceClient:promptProduct(Products.starterPack)
			end,
		}),
	})
end
