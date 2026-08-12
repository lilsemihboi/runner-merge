--!nonstrict

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Vide = require(ReplicatedStorage.Packages.Vide)
const Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)
const Rarities = require(ReplicatedStorage.Shared.Modules.Items.Rarities)
const Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)
const ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
const FormatPercent = require(ReplicatedStorage.Shared.Modules.Ui.FormatPercent)
const Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
const ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
const TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
const Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
const MonetizationServiceUtils = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceUtils)
const RobuxButton = require(ReplicatedStorage.Shared.UI.App.Components.RobuxButton)
const usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)
const ShopContentFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopContentFrame)
const ShopFrame = require(ReplicatedStorage.Shared.UI.Shop.Components.ShopFrame)

type MonetizationProduct = MonetizationServiceUtils.MonetizationProduct

-- A shop section is exactly one ScrollingFrame page wide (1008px at 1x scale) and the scroll
-- view only scrolls vertically, so a row wider than the section renders past the shop panel
-- instead of wrapping. Three cards plus two gaps must fit inside SECTION_WIDTH:
-- 3 * 316 + 2 * 18 = 984, which leaves 12px each side for the card strokes.
const SECTION_WIDTH = 1008
const CARD_WIDTH = 316
const CARD_HEIGHT = 418
const CARD_GAP = 18
-- The row must be at least as tall as a card. The section measures its own height from this
-- container, so a shorter row would let the cards overlap the neighbouring sections.
const ROW_HEIGHT = CARD_HEIGHT + 12

const TITLE_TOP = 10
const TITLE_HEIGHT = 44
const CRATE_IMAGE_SIZE = 148
const CRATE_IMAGE_CENTER_SCALE = 0.315

-- Preview reel geometry, in card-local design pixels.
const REEL_TOP = 214
const REEL_HEIGHT = 116
const REEL_INSET = 20
const REEL_FADE_WIDTH = 34
const PREVIEW_TILE_WIDTH = 88
const PREVIEW_TILE_HEIGHT = 100
const PREVIEW_TILE_GAP = 8
const PREVIEW_CELL = PREVIEW_TILE_WIDTH + PREVIEW_TILE_GAP
const PREVIEW_SCROLL_PIXELS_PER_SECOND = 26

-- Buttons live in a centred row rather than at hand-tuned offsets, so the pair can never
-- reach past the card: 132 + 12 + 132 = 276 inside a 316 - 32 = 284 wide row.
const BUTTON_ROW_INSET = 32
const BUTTON_WIDTH = 132
const BUTTON_HEIGHT = 56
const BUTTON_GAP = 12

const WHITE = Color3.fromRGB(255, 255, 255)
const REEL_BACKING_COLOR = Color3.fromRGB(6, 12, 20)
const HEAVY_FONT = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)

const function shade(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

--[=[
	Loot ids for a crate, ordered by trail multiplier so the preview always reads from the
	most common outcome up to the rarest.
]=]
const function sortedLootIds(crateId: number): { number }
	local crate = Blocks.getBlock(crateId)
	local trailIds = {}

	if not crate or not crate.loot then
		return trailIds
	end

	for trailId in crate.loot do
		table.insert(trailIds, trailId)
	end

	table.sort(trailIds, function(left, right)
		return Trails[left].trailMultiplier < Trails[right].trailMultiplier
	end)

	return trailIds
end

--[=[
	One preview cell: the trail's colours, its cash multiplier, and its drop chance out of
	this specific crate.
]=]
const function previewTile(crateId: number, trailId: number, layoutOrder: number)
	local trail = Trails[trailId]
	local rarityColor = Rarities[trail.trailRarity] or WHITE

	return Frame({
		LayoutOrder = layoutOrder,
		Size = usePx.offset(PREVIEW_TILE_WIDTH, PREVIEW_TILE_HEIGHT),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.08,

		Vide.create("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, shade(rarityColor, 0.38)),
				ColorSequenceKeypoint.new(1, shade(rarityColor, 0.1)),
			}),
			Rotation = 90,
		}),

		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = rarityColor,
			LineJoinMode = Enum.LineJoinMode.Miter,
			Thickness = usePx(3),
			Transparency = 0.35,
		}),

		ImageLabel({
			Image = "rbxassetid://72492959002100",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.29),
			Size = usePx.offset(48, 48),
			ZIndex = 1,

			Vide.create("UIGradient", {
				Color = trail.trailColorSequence,
				Rotation = 60,
			}),
		}),

		TextLabel({
			Text = string.format("x%.2f", trail.trailMultiplier),
			Size = usePx.udim2(0.92, 0, 0, 22),
			Position = usePx.udim2(0.5, 0, 0, 54),
			AnchorPoint = Vector2.new(0.5, 0),
			TextColor3 = WHITE,
			TextScaled = true,
			FontFace = HEAVY_FONT,
			Stroke = { Thickness = usePx(3) },
			ZIndex = 2,
		}),

		TextLabel({
			Text = FormatPercent(Blocks.getOdds(crateId, trailId)),
			Size = usePx.udim2(0.92, 0, 0, 24),
			Position = usePx.udim2(0.5, 0, 0, 74),
			AnchorPoint = Vector2.new(0.5, 0),
			TextColor3 = rarityColor,
			TextScaled = true,
			FontFace = HEAVY_FONT,
			Stroke = { Thickness = usePx(3) },
			ZIndex = 2,
		}),
	})
end

--[=[
	Darkens one end of the reel so tiles look like they slide in and out of a window rather
	than appearing at a hard edge.
]=]
const function edgeFade(anchorX: number, rotation: number)
	return Frame({
		AnchorPoint = Vector2.new(anchorX, 0),
		Position = UDim2.fromScale(anchorX, 0),
		Size = usePx.udim2(0, REEL_FADE_WIDTH, 1, 0),
		BackgroundColor3 = REEL_BACKING_COLOR,
		BackgroundTransparency = 0,
		ZIndex = 3,

		Vide.create("UIGradient", {
			Rotation = rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

--[=[
	A looping marquee of everything the crate can drop.

	The strip renders the loot list twice and is shifted left by exactly one list width per
	cycle, so the moment the shift wraps back to zero the tile that took each slot is
	identical to the one that left it and the loop is seamless. Shifting by a fraction of the
	scaled list width keeps that true at every usePx scale.
]=]
const function previewReel(crateId: number)
	local trailIds = sortedLootIds(crateId)

	if #trailIds == 0 then
		return Frame({ Size = UDim2.fromScale(0, 0) })
	end

	local loopWidth = #trailIds * PREVIEW_CELL
	local loopWidthPx = usePx(loopWidth)
	local shift = Vide.source(0)

	Vide.cleanup(RunService.RenderStepped:Connect(function(deltaTime)
		shift((shift() + deltaTime * PREVIEW_SCROLL_PIXELS_PER_SECOND) % loopWidth)
	end))

	local tiles = {}
	for pass = 0, 1 do
		for index, trailId in trailIds do
			table.insert(tiles, previewTile(crateId, trailId, pass * #trailIds + index))
		end
	end

	return Frame({
		Name = "LootPreview",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = usePx.udim2(1, -REEL_INSET, 0, REEL_HEIGHT),
		Position = usePx.udim2(0.5, 0, 0, REEL_TOP),
		BackgroundColor3 = REEL_BACKING_COLOR,
		BackgroundTransparency = 0.25,
		ClipsDescendants = true,
		ZIndex = 2,

		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = usePx(3),
			Transparency = 0.35,
		}),

		Frame({
			Name = "Strip",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			Position = function()
				return UDim2.fromOffset(-math.round(shift() / loopWidth * loopWidthPx()), 0)
			end,

			Vide.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = usePx.udim(0, PREVIEW_TILE_GAP),
			}),

			table.unpack(tiles),
		}),

		edgeFade(0, 0),
		edgeFade(1, 180),
	})
end

type CrateCardProps = {
	crateId: number,
	image: string,
	layoutOrder: number,
	singleProduct: MonetizationProduct,
	tripleProduct: MonetizationProduct,
	studFrame: (props: any) -> Instance,
}

const function crateCard(props: CrateCardProps)
	return props.studFrame({
		Size = usePx.offset(CARD_WIDTH, CARD_HEIGHT),
		LayoutOrder = props.layoutOrder,

		TextLabel({
			Text = Blocks.getBlock(props.crateId).blockName,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = usePx.udim2(0.5, 0, 0, TITLE_TOP),
			Size = usePx.udim2(0.88, 0, 0, TITLE_HEIGHT),
			TextScaled = true,
			TextWrapped = false,
			TextColor3 = WHITE,
			Font = Enum.Font.BuilderSansExtraBold,
			Stroke = { Thickness = usePx(3), Color = Color3.fromRGB(0, 0, 0) },
			ZIndex = 3,
		}),

		ImageLabel({
			Image = props.image,
			Size = usePx.offset(CRATE_IMAGE_SIZE, CRATE_IMAGE_SIZE),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, CRATE_IMAGE_CENTER_SCALE),
			ZIndex = 1,
		}),

		previewReel(props.crateId),

		Frame({
			Size = usePx.udim2(1, -BUTTON_ROW_INSET, 0, BUTTON_HEIGHT),
			Position = UDim2.fromScale(0.5, 0.885),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 4,

			Vide.create("UIListLayout", {
				Padding = usePx.udim(0, BUTTON_GAP),
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),

			RobuxButton({
				Colors = ButtonColors.Green,
				LayoutOrder = 1,
				product = props.singleProduct,
				Size = usePx.offset(BUTTON_WIDTH, BUTTON_HEIGHT),
			}),

			RobuxButton({
				Colors = ButtonColors.Blue,
				LayoutOrder = 2,
				Text = "3x",
				TextWrapped = false,
				product = props.tripleProduct,
				Size = usePx.offset(BUTTON_WIDTH, BUTTON_HEIGHT),
			}),
		}),
	})
end

const function container()
	return Frame({
		Size = usePx.offset(SECTION_WIDTH, ROW_HEIGHT),
		BackgroundTransparency = 1,

		Vide.create("UIListLayout", {
			Padding = usePx.udim(0, CARD_GAP),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		crateCard({
			crateId = 10,
			image = "rbxassetid://85954689053924",
			layoutOrder = 1,
			singleProduct = Products.crate1,
			tripleProduct = Products.x3crate1,
			studFrame = ShopFrame.Blue,
		}),

		crateCard({
			crateId = 11,
			image = "rbxassetid://78989028588239",
			layoutOrder = 2,
			singleProduct = Products.crate2,
			tripleProduct = Products.x3crate2,
			studFrame = ShopFrame.Grey,
		}),

		crateCard({
			crateId = 12,
			image = "rbxassetid://126669563497914",
			layoutOrder = 3,
			singleProduct = Products.crate3,
			tripleProduct = Products.x3crate3,
			studFrame = ShopFrame.Orange,
		}),
	})
end

return function()
	return ShopContentFrame({
		Text = "~Crates~",
		LayoutOrder = 2,
		Padding = 5,

		container(),
	})
end
