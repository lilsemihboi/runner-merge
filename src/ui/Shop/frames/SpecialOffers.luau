--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Abbreviate = require(ReplicatedStorage.Shared.Modules.Ui.Abbreviate)
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local CarIds = require(ReplicatedStorage.Shared.Modules.Items.CarIds)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local RobuxButton = require(ReplicatedStorage.Shared.UI.App.Components.RobuxButton)
local RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)
local ShopContentFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopContentFrame)
local ShopFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopFrame)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
const Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)
const ExclusiveCars = require(ReplicatedStorage.Shared.Modules.Items.ExclusiveCars)
const FormatPercent = require(ReplicatedStorage.Shared.Modules.Ui.FormatPercent)
const Rarities = require(ReplicatedStorage.Shared.Modules.Items.Rarities)
const Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)
const RewardedAdServiceClient = require(ReplicatedStorage.Shared.Services.RewardedAdService.RewardedAdServiceClient)
const RewardedAdSlice = require(ReplicatedStorage.Shared.UI.Hud.RewardedAdSlice)
const useStock = require(ReplicatedStorage.Shared.Services.StockService.Hooks.useStock)
const StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

-- Rarity breakdown geometry, in offer-local design pixels. The offer frame is far wider
-- than a crate card, so the list stretches across the space right of the crate icon.
const GRID_LEFT = 260
const GRID_TOP = 72
const GRID_WIDTH = 490
const RARITY_ROW_HEIGHT = 46
const RARITY_ROW_GAP = 8

const WHITE = Color3.fromRGB(255, 255, 255)
const HEAVY_FONT = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
const SUNRAY_IMAGE = "rbxassetid://77656565126814"

--[=[
	A static sunray behind the crate icon. Same image and look as the crate cards in
	Crates.luau, but fixed in place rather than animated. No rotation: setting Rotation on
	gui elements inside a ScrollingFrame glitches in the engine.
]=]
const function sunray(x: number, y: number, size: number)
	return ImageLabel({
		Name = "Sunray",
		Image = SUNRAY_IMAGE,
		Size = usePx.offset(size, size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = usePx.udim2(0, x, 0, y),
		ImageColor3 = WHITE,
		ImageTransparency = 0.2,
		ZIndex = 0,
	})
end

--[=[
	Rarity tiers in display order, matching the id bands in Blocks.luau from common to
	rarest.
]=]
const RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

--[=[
	Totals each trail's drop chance in a crate per rarity tier, so the breakdown reads as
	"Rare - 58%" instead of one line per trail.
]=]
const function rarityChances(crateId: number): { { name: string, chance: number } }
	local crate = Blocks.getBlock(crateId)
	local totals = {}

	if not crate or not crate.loot then
		return {}
	end

	for trailId, weight in crate.loot do
		local rarity = Trails[trailId].trailRarity
		totals[rarity] = (totals[rarity] or 0) + weight
	end

	local chances = {}
	for _, rarity in RARITY_ORDER do
		local chance = totals[rarity]
		if chance then
			table.insert(chances, { name = rarity, chance = chance })
		end
	end

	return chances
end

--[=[
	One rarity row: the tier name on the left and its combined drop chance on the right,
	styled like the Index menu buttons with inner and outer strokes.
]=]
const function rarityRow(name: string, chance: number, layoutOrder: number)
	local rarityColor = Rarities[name] or WHITE

	return Frame({
		LayoutOrder = layoutOrder,
		Size = usePx.udim2(1, 0, 0, RARITY_ROW_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		ClipsDescendants = true,

		-- Inner stroke
		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = Color3.fromRGB(255, 255, 255),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = usePx(4),
			Transparency = 0.5,
		}),

		-- Outer stroke
		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			BorderStrokePosition = Enum.BorderStrokePosition.Outer,
			Color = Color3.fromRGB(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = usePx(4),
			Transparency = 0.5,
		}),

		-- Tier name
		TextLabel({
			Text = name,
			Size = usePx.udim2(0.6, 0, 1, 0),
			Position = usePx.udim2(0.02, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			TextColor3 = rarityColor,
			TextScaled = true,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = HEAVY_FONT,
			Stroke = { Thickness = usePx(2) },
			ZIndex = 2,
		}),

		-- Drop chance
		TextLabel({
			Text = FormatPercent(chance),
			Size = usePx.udim2(0.4, 0, 1, 0),
			Position = usePx.udim2(0.98, 0, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextColor3 = WHITE,
			TextScaled = true,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = HEAVY_FONT,
			Stroke = { Thickness = usePx(2) },
			ZIndex = 2,
		}),
	})
end

--[=[
	A static list of every rarity tier the crate can drop, styled like the Index menu buttons.
]=]
const function rarityList(crateId: number)
	local chances = rarityChances(crateId)

	if #chances == 0 then
		return Frame({ Size = UDim2.fromScale(0, 0) })
	end

	local rows = {}
	for index, entry in chances do
		table.insert(rows, rarityRow(entry.name, entry.chance, index))
	end

	local listHeight = #chances * RARITY_ROW_HEIGHT + (#chances - 1) * RARITY_ROW_GAP

	return Frame({
		Name = "RarityList",
		AnchorPoint = Vector2.new(0, 0),
		Size = usePx.udim2(0, GRID_WIDTH, 0, listHeight),
		Position = usePx.udim2(0, GRID_LEFT, 0, GRID_TOP),
		BackgroundTransparency = 1,
		ZIndex = 2,

		Vide.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = usePx.udim(0, RARITY_ROW_GAP),
		}),

		table.unpack(rows),
	})
end

const function freeHeartCrate()
	RewardedAdSlice.refresh()

	return ShopFrame.Purple({
		Size = usePx.offset(1008, 250),
		LayoutOrder = 0,
		Visible = function()
			return RewardedAdSlice.canShowAd()
		end,

		--Title
		TextLabel({
			Text = "FREE Heart Crate",
			Size = UDim2.fromScale(1, 0.2),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Position = usePx.udim2(0, 0, 0, 10),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		-- Sunrays behind the crate icon
		sunray(120, 137.5, 320),
		sunray(120, 137.5, 230),
		sunray(120, 137.5, 160),
		sunray(120, 137.5, 110),

		-- Crate Icon rbxassetid://119203883334161 On left side Center

		ImageLabel({
			Image = "rbxassetid://119203883334161",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0, 120, 0.55, 0),
			Size = usePx.offset(229, 229),
		}),

		rarityList(13),

		StudButton({
			Colors = ButtonColors.Blue,
			Text = "Watch AD",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.87, 0, 0.78, 0),
			Size = usePx.offset(200, 70),
			OnClick = function()
				local isSuccess, result = RewardedAdServiceClient:playAd()
				if isSuccess and result == Enum.ShowAdResult.ShowCompleted then
					RewardedAdSlice.canShowAd(false)
				end
			end,
		}),
	})
end

local function carBundle()
	return ShopFrame.Orange({
		Size = usePx.offset(1008, 250),
		LayoutOrder = 0,

		--Title
		TextLabel({
			Text = "Exclusive Car Bundle",
			Size = UDim2.fromScale(1, 0.2),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Position = usePx.udim2(0, 0, 0, 10),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		--Worths
		TextLabel({
			Text = "\u{E002}399",
			Size = usePx.offset(200, 45),
			Position = usePx.udim2(0, 780, 0, 100),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.BuilderSansExtraBold,
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,

			-- Red stick
			Frame({
				Size = UDim2.new(0.7, 0, 0, 5),
				Position = UDim2.fromScale(0.5, 0.45),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = -15,
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				BorderSizePixel = 0,
				BackgroundTransparency = 0,
			}),
		}),

		-- CONTENT
		Frame({
			Size = usePx.offset(700, 160),
			Position = usePx.udim2(0, 380, 0, 150),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,

			Vide.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = usePx.udim(0, 20),
			}),

			ShopFrame.Grey({
				Size = UDim2.fromScale(0.9, 0.9),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 1,

				TextLabel({
					Text = `{CarIds[14].name}`,
					Size = UDim2.fromScale(1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = CarIds[14].imageId,
					Size = UDim2.fromScale(1, 1),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.45, 0.45),
				}),

				TextLabel({
					Text = `Level 14`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
				}),
			}),

			TextLabel({
				Text = "+",
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				ZIndex = 99,
				LayoutOrder = 2,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Size = UDim2.fromScale(0.07, 0.9),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Stroke = {
					Thickness = usePx(4),
				},
			}),

			ShopFrame.Grey({
				Size = UDim2.fromScale(0.9, 0.9),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 3,

				TextLabel({
					Text = `{CarIds[15].name}`,
					Size = UDim2.fromScale(1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = CarIds[15].imageId,
					Size = UDim2.fromScale(1, 1),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.45, 0.45),
				}),

				TextLabel({
					Text = `Level 15`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
				}),
			}),

			TextLabel({
				Text = "+",
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				ZIndex = 99,
				LayoutOrder = 4,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Size = UDim2.fromScale(0.07, 0.9),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Stroke = {
					Thickness = usePx(4),
				},
			}),

			ShopFrame.Grey({
				Size = UDim2.fromScale(0.9, 0.9),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 5,

				TextLabel({
					Text = `{CarIds[16].name}`,
					Size = UDim2.fromScale(1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = CarIds[16].imageId,
					Size = UDim2.fromScale(1, 1),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.45, 0.45),
				}),

				TextLabel({
					Text = `Level 16`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
				}),
			}),
		}),

		TextLabel({
			Text = "Limited Time",
			TextScaled = true,
			Size = usePx.offset(200, 45),
			Position = usePx.udim2(0, 780, 0, 10),
			TextColor3 = Color3.fromRGB(255, 0, 0),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(87, 0, 0) },
			ZIndex = 3,
		}),

		RobuxButton({
			Colors = ButtonColors.Green,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.84, 0, 0.78, 0),
			product = Products.carBundle1,
			Size = usePx.offset(200, 70),
		}),
	})
end

local PRODUCT_KEY = "exclusiveCar"

local function exclusiveCar()
	local carInfo = ExclusiveCars.get(ExclusiveCars.ids.exclusiveCar)
	local remaining = useStock(PRODUCT_KEY)
	local limit = Products.exclusiveCar.stock

	local isSoldOut = Vide.derive(function()
		return remaining() <= 0
	end)

	return ShopFrame.Gold({
		Size = usePx.offset(1008, 250),
		LayoutOrder = 1,

		--Title
		TextLabel({
			Text = "Limited Car",
			Size = UDim2.fromScale(1, 0.2),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Position = usePx.udim2(0, 0, 0, 10),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		-- Stock counter. Turns red once it runs out.
		TextLabel({
			Text = function()
				if isSoldOut() then
					return "SOLD OUT"
				end

				return `{remaining()} / {limit} left`
			end,
			TextColor3 = function()
				if isSoldOut() then
					return Color3.fromRGB(255, 64, 64)
				end

				return Color3.fromRGB(255, 236, 150)
			end,
			Size = usePx.offset(260, 45),
			Position = usePx.udim2(0, 728, 0, 20),
			TextScaled = true,
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(87, 47, 0) },
			ZIndex = 3,
		}),

		-- CONTENT
		Frame({
			Size = usePx.offset(700, 160),
			Position = usePx.udim2(0, 380, 0, 150),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,

			Vide.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = usePx.udim(0, 20),
			}),

			ShopFrame.Grey({
				Size = UDim2.fromScale(0.9, 0.9),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 1,

				TextLabel({
					Text = carInfo.name,
					Size = UDim2.fromScale(1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = carInfo.imageId,
					Size = UDim2.fromScale(1, 1),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.45, 0.45),
				}),

				TextLabel({
					Text = `${Abbreviate(carInfo.incomePerLap)}/lap`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Gradient = {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 255, 192)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 255, 0)),
						}),
						Rotation = 90,
					},
				}),
			}),
		}),

		TextLabel({
			Text = "Cannot be merged",
			TextScaled = true,
			Size = usePx.offset(260, 40),
			Position = usePx.udim2(0, 728, 0, 72),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		RobuxButton({
			Colors = function()
				-- The click is already refused in promptProduct; this just stops
				-- the button from looking purchasable.
				if isSoldOut() then
					return ButtonColors.Red
				end

				return ButtonColors.Green
			end,
			HideGift = function()
				if remaining() <= 0 then
					return true
				else
					return false
				end
			end,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.84, 0, 0.78, 0),
			product = Products.exclusiveCar,
			Size = usePx.offset(200, 70),
		}),
	})
end

local function starterPack()
	local owns = Vide.source(MonetizationServiceClient:ownsOneTimePurchase(Products.starterPack))

	if owns() then
		return nil
	end

	MonetizationServiceClient:getProductInfoChangedSignal(Products.starterPack):Connect(function()
		owns(MonetizationServiceClient:ownsOneTimePurchase(Products.starterPack))
	end)

	return ShopFrame.Blue({
		Size = usePx.offset(1008, 230),
		LayoutOrder = 0,
		Visible = function()
			return not owns()
		end,
		--Title
		TextLabel({
			Text = "Starter Pack",
			Size = UDim2.fromScale(1, 0.2),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
			Position = usePx.udim2(0, 0, 0, 10),
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		--Worths
		TextLabel({
			Text = "\u{E002}149",
			Size = usePx.offset(200, 45),
			Position = usePx.udim2(0, 780, 0, 70),
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.BuilderSansExtraBold,
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,

			-- Red stick
			Frame({
				Size = UDim2.new(0.7, 0, 0, 5),
				Position = UDim2.fromScale(0.5, 0.45),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = -15,
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				BorderSizePixel = 0,
				BackgroundTransparency = 0,
			}),
		}),

		-- Frame Content
		Frame({
			Size = usePx.offset(700, 160),
			Position = UDim2.fromScale(0.005, 0.98),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,

			Vide.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = usePx.udim(0, 20),
			}),

			-- Level 6 Car
			ShopFrame.Orange({
				Size = UDim2.fromScale(0.80, 0.80),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 1,

				TextLabel({
					Text = `{CarIds[6].name:upper()}`,
					Size = UDim2.fromScale(1.1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = usePx(20),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				-- Car Image
				ImageLabel({
					BackgroundTransparency = 1,
					Image = CarIds[6].imageId,
					Size = UDim2.fromScale(0.95, 0.95),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.46, 0.45),
				}),

				-- Car Bonus
				TextLabel({
					Text = `${Abbreviate(RunnerUtils.getRunnerIncomePerLap(6))}/lap`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Gradient = {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 255, 192)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 255, 0)),
						}),
						Rotation = 90,
					},
				}),
			}),

			TextLabel({
				Text = "+",
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				ZIndex = 99,
				LayoutOrder = 2,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Size = UDim2.fromScale(0.07, 0.9),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Stroke = {
					Thickness = usePx(4),
				},
			}),

			ShopFrame.Green({
				Size = UDim2.fromScale(0.80, 0.80),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 3,

				TextLabel({
					Text = `MONEY`,
					Size = UDim2.fromScale(1.1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = usePx(20),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = "rbxassetid://117630190830410",
					Size = UDim2.fromScale(0.80, 0.80),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
				}),

				TextLabel({
					Text = `+$50k`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Gradient = {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 255, 192)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 255, 0)),
						}),
						Rotation = 90,
					},
				}),
			}),

			TextLabel({
				Text = "+",
				FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
				ZIndex = 99,
				LayoutOrder = 4,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Size = UDim2.fromScale(0.07, 0.9),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Stroke = {
					Thickness = usePx(4),
				},
			}),

			ShopFrame.Green({
				Size = UDim2.fromScale(0.80, 0.80),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 5,

				TextLabel({
					Text = `MONEY BONUS`,
					Size = UDim2.fromScale(1.1, 0.25),
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					Position = UDim2.fromScale(0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = usePx(20),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
				}),

				ImageLabel({
					Image = "rbxassetid://121313278016619",
					Size = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.75, 0.33),
					BackgroundTransparency = 1,
					ZIndex = 2,
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
				}),

				ImageLabel({
					BackgroundTransparency = 1,
					Image = "rbxassetid://117630190830410",
					Size = UDim2.fromScale(0.80, 0.80),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
				}),

				TextLabel({
					Text = `+20%`,
					Size = UDim2.fromScale(1.1, 0.25),
					Position = UDim2.fromScale(0.5, 1.1),
					AnchorPoint = Vector2.new(0.5, 1),
					Stroke = { Thickness = usePx(2) },
					ZIndex = 99,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,
					Gradient = {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(226, 255, 192)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 255, 0)),
						}),
						Rotation = 90,
					},
				}),
			}),
		}),

		RobuxButton({
			Colors = ButtonColors.Green,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = usePx.udim2(0.87, 0, 0.78, 0),
			product = Products.starterPack,
			Size = usePx.offset(200, 70),
		}),
	})
end

return function()
	return ShopContentFrame({
		Text = "~Special Offer~",
		LayoutOrder = 0,
		Padding = 5,

		freeHeartCrate(),
		starterPack(),
		carBundle(),
		exclusiveCar(),
	})
end
