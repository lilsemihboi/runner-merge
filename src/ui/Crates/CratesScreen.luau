--!nonstrict

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const Vide = require(ReplicatedStorage.Packages.Vide)
const VideCharm = require(ReplicatedStorage.Packages.VideCharm)
const CratesSlice = require(script.Parent.CratesSlice)
const Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)
const Rarities = require(ReplicatedStorage.Shared.Modules.Items.Rarities)
const Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)
const ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
const FormatPercent = require(ReplicatedStorage.Shared.Modules.Ui.FormatPercent)
const Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
const ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
const TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
const SoundServiceClient = require(ReplicatedStorage.Shared.Services.SoundService.SoundServiceClient)
const Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
const StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
const usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)
const HudSlice = require(ReplicatedStorage.Shared.UI.Hud.HudSlice)

const STRIP_LENGTH = 50
const WINNER_INDEX = 46
const SPIN_INFO = TweenInfo.new(Blocks.rollTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
-- At the start of the Quint ease-out a tile crosses the marker every frame. `play` restarts one
-- shared Sound instance, so ticking that fast only ever plays the attack transient and buzzes.
const MIN_TICK_INTERVAL = 0.045
-- How long a reveal stays on screen before a queued roll takes over the reel.
const REVEAL_HOLD = Blocks.revealHold

const PANEL_WIDTH = 1358
const PANEL_HEIGHT = 470
const REEL_TOP = 88
const REEL_HEIGHT = 245
const REEL_CENTER_Y = REEL_TOP + REEL_HEIGHT // 2
const TILE_SIZE = 235
const TILE_GAP = 18
const FADE_WIDTH = 120

const PANEL_COLOR = Color3.fromRGB(7, 15, 24)
const WHITE = Color3.fromRGB(255, 255, 255)
const HEAVY_FONT = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)
const BOLD_FONT = Font.new("rbxassetid://11702779517", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

const CENTERED_POSITION = UDim2.fromScale(0.5, 0.5)
-- Anchor is centred, so -0.5 scale parks the whole frame above the top edge regardless of height.
const ABOVE_SCREEN_POSITION = UDim2.fromScale(0.5, -0.5)
const SLIDE_IN_PERIOD = 0.35
const SLIDE_IN_DAMPING = 0.8
const BACKDROP_TRANSPARENCY = 0.42

-- The strip is parked with its centre on the viewport's left edge before every spin, so the
-- offset measured afterwards is always relative to the same starting point.
const REEL_START_POSITION = UDim2.fromScale(0, 0.5)

const RAY_SPIN_DEGREES_PER_SECOND = 14
const MARKER_IDLE_COLOR = Color3.fromRGB(255, 53, 97)
const SUNRAY_IMAGE = "rbxassetid://77656565126814"

-- Hoisted because these are read inside per-frame prop closures, where `usePx(n)` would
-- otherwise allocate a fresh reader on every spring step.
const RAYS_SIZE_PX = usePx(340)
const BEAM_BASE_PX = usePx(4)
const BEAM_KICK_PX = usePx(7)
const TILE_RIM_PX = usePx(4)
const RESULT_TOP_PX = usePx(REEL_TOP + REEL_HEIGHT + 32)
const RESULT_SLIDE_PX = usePx(20)

const function getTrailIds(loot: { [number]: number }): { number }
	local ids = {}
	for trailId in loot do
		table.insert(ids, trailId)
	end
	return ids
end

const function buildStrip(crateId: number, winningTrailId: number): { number }
	local crate = Blocks.getBlock(crateId)
	local strip = table.create(STRIP_LENGTH)

	if not crate or not crate.loot then
		warn("[buildStrip] missing crate/loot for crateId", crateId)
		return strip
	end

	local trailIds = getTrailIds(crate.loot)
	if #trailIds == 0 then
		warn("[buildStrip] empty loot table for crateId", crateId)
		return strip
	end

	for i = 1, STRIP_LENGTH do
		if i == WINNER_INDEX then
			strip[i] = winningTrailId
		else
			strip[i] = trailIds[math.random(1, #trailIds)]
		end
	end

	return strip
end

const function shade(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

const function revealRays(color: () -> Color3, reveal: () -> number, rotation: () -> number)
	return Frame({
		Name = "RevealRays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = usePx.udim2(0.5, 0, 0, REEL_CENTER_Y),
		Size = function()
			local size = RAYS_SIZE_PX() * reveal()
			return UDim2.fromOffset(size, size)
		end,
		BackgroundTransparency = 1,
		ZIndex = 0,

		ImageLabel({
			Name = "Sunray",
			Image = SUNRAY_IMAGE,
			Size = UDim2.fromScale(1, 1),
			ImageColor3 = function()
				return color():Lerp(WHITE, 0.3)
			end,
			ImageTransparency = function()
				return 1 - 0.8 * reveal()
			end,
			BackgroundTransparency = 1,
			Rotation = rotation,
			ZIndex = 0,
		}),
	})
end

--[=[
	Darkens the reel towards its edges so tiles appear to fly in and out of the frame rather
	than popping in at a hard boundary.
]=]
const function edgeFade(anchorX: number, rotation: number)
	return Frame({
		Name = "EdgeFade",
		AnchorPoint = Vector2.new(anchorX, 0),
		Position = UDim2.fromScale(anchorX, 0),
		Size = usePx.udim2(0, FADE_WIDTH, 1, 0),
		BackgroundColor3 = PANEL_COLOR,
		BackgroundTransparency = 0,
		ZIndex = 5,

		Vide.create("UIGradient", {
			Rotation = rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.55, 0.8),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

--[=[
	The centre line the winning tile lands on. `kick` briefly widens and brightens the beam
	every time a tile crosses it, which reads as the reel physically clicking past a notch.
]=]
const function reelMarker(color: () -> Color3, kick: () -> number)
	local function arrow(positionY: number)
		return Frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, positionY),
			Size = usePx.offset(18, 18),
			Rotation = 45,
			BackgroundColor3 = color,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
		})
	end

	return Frame({
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = usePx.udim2(0.5, 0, 0, REEL_CENTER_Y),
		Size = usePx.offset(24, REEL_HEIGHT + 28),
		BackgroundTransparency = 1,
		ZIndex = 6,

		Frame({
			Name = "Beam",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				return UDim2.new(0, BEAM_BASE_PX() + BEAM_KICK_PX() * kick(), 1, 0)
			end,
			BackgroundColor3 = color,
			BackgroundTransparency = function()
				return 0.15 - 0.15 * kick()
			end,
			BorderSizePixel = 0,
		}),

		arrow(0),
		arrow(1),
	})
end

--[=[
	One reel cell. Every visual is bound to the trail source rather than read once, because
	`Vide.indexes` keys tiles by position and reuses them when a queued roll swaps the strip.
]=]
const function reelTile(trailId: () -> number, index: number, crateId: () -> number?, isRevealed: () -> boolean)
	local trail = Vide.derive(function()
		return Trails[trailId()] or Trails[1]
	end)

	local rarityColor = Vide.derive(function()
		return Rarities[trail().trailRarity] or WHITE
	end)

	local highlight = Vide.spring(
		Vide.derive(function()
			return if index == WINNER_INDEX and isRevealed() then 1 else 0
		end),
		0.3,
		0.55
	)

	return Frame({
		Name = `Reel{index}`,
		LayoutOrder = index,
		Size = usePx.offset(TILE_SIZE, TILE_SIZE),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.1,

		Vide.create("UIGradient", {
			Color = function()
				local base = rarityColor()
				return ColorSequence.new({
					ColorSequenceKeypoint.new(0, shade(base, 0.36)),
					ColorSequenceKeypoint.new(1, shade(base, 0.08)),
				})
			end,
			Rotation = 90,
		}),

		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = rarityColor,
			LineJoinMode = Enum.LineJoinMode.Miter,
			Thickness = function()
				return TILE_RIM_PX() * (1 + highlight())
			end,
			Transparency = function()
				return 0.45 - 0.45 * highlight()
			end,
		}),

		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			BorderStrokePosition = Enum.BorderStrokePosition.Outer,
			Color = Color3.fromRGB(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = usePx(6),
			Transparency = 0.45,
		}),

		-- Rarity wash that blooms behind the winner's contents once the reel stops.
		Frame({
			Name = "Highlight",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = rarityColor,
			BackgroundTransparency = function()
				return 1 - 0.3 * highlight()
			end,
			ZIndex = 0,
		}),

		TextLabel({
			Size = usePx.udim2(0.9, 0, 0, 42),
			Position = usePx.udim2(0.5, 0, 0, 6),
			AnchorPoint = Vector2.new(0.5, 0),
			Text = function()
				return trail().trailName
			end,
			TextColor3 = WHITE,
			Stroke = { Thickness = usePx(4) },
			ZIndex = 3,
			TextScaled = true,
			FontFace = HEAVY_FONT,
		}),

		ImageLabel({
			Image = "rbxassetid://112932658180628",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.35, 0.4),
			Size = usePx.offset(64, 64),
			ZIndex = 2,
		}),

		ImageLabel({
			Image = "rbxassetid://72492959002100",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.58, 0.575),
			Size = usePx.offset(96, 96),
			ZIndex = 1,

			Vide.create("UIGradient", {
				Color = function()
					return trail().trailColorSequence
				end,
				Rotation = 60,
			}),
		}),

		TextLabel({
			Size = usePx.offset(128, 40),
			Position = usePx.udim2(0, 154, 0, 146),
			AnchorPoint = Vector2.new(0.5, 0),
			Text = function()
				return string.format("x%.2f", trail().trailMultiplier)
			end,
			TextColor3 = WHITE,
			Stroke = { Thickness = usePx(4) },
			ZIndex = 3,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = HEAVY_FONT,
		}),

		TextLabel({
			Size = usePx.offset(128, 44),
			Position = usePx.udim2(0, 154, 0, 186),
			AnchorPoint = Vector2.new(0.5, 0),
			Text = function()
				return FormatPercent(Blocks.getOdds(crateId(), trailId()))
			end,
			TextColor3 = rarityColor,
			Stroke = { Thickness = usePx(4) },
			ZIndex = 3,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			FontFace = HEAVY_FONT,
		}),

		TextLabel({
			Size = usePx.offset(90, 26),
			Position = usePx.udim2(0, 10, 0, 200),
			Text = function()
				return trail().trailRarity
			end,
			TextColor3 = rarityColor,
			Stroke = { Thickness = usePx(3) },
			ZIndex = 3,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = BOLD_FONT,
		}),
	})
end

const function rollScreen()
	local rollData = VideCharm.useAtom(CratesSlice.states.rollData)
	local isRolling = VideCharm.useAtom(CratesSlice.states.isRolling)
	local pendingRolls = VideCharm.useAtom(CratesSlice.states.pendingRolls)
	local rollNumber = VideCharm.useAtom(CratesSlice.states.rollNumber)
	local rollCount = VideCharm.useAtom(CratesSlice.states.rollCount)

	local rollStrip = Vide.source({})
	local containerRef: Frame? = nil
	local itemsFrameRef: Frame? = nil

	-- Every spin is tagged so a queued roll starting mid-flight cannot be driven by the
	-- previous spin's deferred thread, tick loop, or tween completion.
	local spinToken = 0

	-- `Vide.show` rebuilds this whole tree per open, so the springs start at their offscreen
	-- values and are retargeted a frame later. Retargeting immediately would let them settle
	-- before the first render and the panel would simply appear.
	local backdropTarget = Vide.source(1)
	local backdrop = Vide.spring(backdropTarget, 0.3, 1)
	local slideTarget = Vide.source(ABOVE_SCREEN_POSITION)
	local slidePosition = Vide.spring(slideTarget, SLIDE_IN_PERIOD, SLIDE_IN_DAMPING)

	local punchTarget = Vide.source(1)
	local punch = Vide.spring(punchTarget, 0.22, 0.4)
	local flashTarget = Vide.source(1)
	local flash = Vide.spring(flashTarget, 0.4, 1)
	local kickTarget = Vide.source(0)
	local kick = Vide.spring(kickTarget, 0.1, 1)
	local raysRotation = Vide.source(0)

	local crateId = Vide.derive(function()
		return rollData().crateId
	end)

	local blockName = Vide.derive(function()
		local crate = Blocks.getBlock(crateId())
		return if crate then crate.blockName else ""
	end)

	local isRevealed = Vide.derive(function()
		return not isRolling() and rollData().trailId ~= nil
	end)

	local wonTrail = Vide.derive(function()
		return Trails[rollData().trailId]
	end)

	local wonColor = Vide.derive(function()
		local trail = wonTrail()
		return if trail then Rarities[trail.trailRarity] or WHITE else WHITE
	end)

	-- The marker only adopts the rarity colour once the roll has landed, so mid-spin it stays
	-- a neutral guide instead of leaking the outcome.
	local markerColor = Vide.derive(function()
		return if isRevealed() then wonColor() else MARKER_IDLE_COLOR
	end)

	local reveal = Vide.spring(
		Vide.derive(function()
			return if isRevealed() then 1 else 0
		end),
		0.35,
		0.6
	)

	local function playRevealImpact()
		SoundServiceClient:play("caseReveal")
		punchTarget(1.035)
		flashTarget(0.55)
		task.delay(0.08, punchTarget, 1)
		task.delay(0.06, flashTarget, 1)
	end

	local function spin(token: number)
		local container = containerRef
		local itemsFrame = itemsFrameRef
		if not container or not itemsFrame then
			return
		end

		-- Park the strip first, then let layout settle, so the winner offset is measured
		-- from a known position even when a previous spin left the strip mid-reel.
		container.Position = REEL_START_POSITION
		RunService.RenderStepped:Wait()
		RunService.RenderStepped:Wait()

		if token ~= spinToken or not container.Parent then
			return
		end

		local winnerTile = container:FindFirstChild("Reel" .. WINNER_INDEX)
		if not winnerTile then
			CratesSlice.actions.finishRolling()
			return
		end

		local frameCenterX = itemsFrame.AbsolutePosition.X + itemsFrame.AbsoluteSize.X * 0.5
		local winnerCenterX = winnerTile.AbsolutePosition.X + winnerTile.AbsoluteSize.X * 0.5
		local targetOffset = frameCenterX - winnerCenterX

		-- Centre-to-centre tile spacing, measured from two adjacent tiles so it stays correct
		-- across resolutions rather than assuming the usePx tile size plus layout padding.
		local cellWidth = math.max(1, winnerTile.AbsoluteSize.X)
		local firstTile = container:FindFirstChild("Reel1")
		local secondTile = container:FindFirstChild("Reel2")
		if firstTile and secondTile then
			cellWidth = math.max(1, math.abs(secondTile.AbsolutePosition.X - firstTile.AbsolutePosition.X))
		end

		local tween = TweenService:Create(container, SPIN_INFO, {
			Position = UDim2.new(0, targetOffset, 0.5, 0),
		})

		-- Decelerating slot ticks: fire once per tile crossing the centre marker. The Quint
		-- ease-out spaces the crossings further apart over time, so the ticks slow to a stop.
		local isTicking = true
		task.spawn(function()
			local lastIndex
			local lastTickClock = 0
			while isTicking and container.Parent do
				local index = math.floor(-container.Position.X.Offset / cellWidth + 0.5)
				local clock = os.clock()
				local hasTicked = lastIndex ~= nil and index ~= lastIndex and clock - lastTickClock >= MIN_TICK_INTERVAL
				if hasTicked then
					SoundServiceClient:play("caseTick")
					lastTickClock = clock
				end
				kickTarget(if hasTicked then 1 else 0)
				lastIndex = index
				RunService.RenderStepped:Wait()
			end
			kickTarget(0)
		end)

		tween.Completed:Connect(function()
			isTicking = false
			if token ~= spinToken then
				return
			end

			CratesSlice.actions.finishRolling()
			playRevealImpact()

			if #CratesSlice.states.pendingRolls() > 0 then
				task.delay(REVEAL_HOLD, CratesSlice.actions.advanceRoll)
			end
		end)
		tween:Play()
	end

	Vide.effect(function()
		local info = rollData()
		if not info or not info.trailId then
			rollStrip({})
			return
		end
		rollStrip(buildStrip(info.crateId, info.trailId))
	end)

	Vide.effect(function()
		local rolling = isRolling()
		local strip = rollStrip()

		if not rolling or #strip == 0 then
			return
		end

		spinToken += 1
		local token = spinToken

		-- Deferred so the refs bound by Vide.action on this render are assigned.
		task.defer(function()
			if token == spinToken then
				spin(token)
			end
		end)
	end)

	Vide.cleanup(RunService.RenderStepped:Connect(function(deltaTime)
		raysRotation((raysRotation() + deltaTime * RAY_SPIN_DEGREES_PER_SECOND) % 360)
	end))

	Vide.cleanup(task.defer(function()
		backdropTarget(BACKDROP_TRANSPARENCY)
		slideTarget(CENTERED_POSITION)
	end))

	return Frame({
		Name = "CratesScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(2, 5, 10),
		BackgroundTransparency = backdrop,

		Frame({
			Name = "Panel",
			Size = usePx.offset(PANEL_WIDTH, PANEL_HEIGHT),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = slidePosition,
			BackgroundColor3 = PANEL_COLOR,
			BackgroundTransparency = 0.35,

			Vide.create("UIScale", {
				Scale = punch,
			}),

			Vide.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(5, 16, 43),
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = usePx(6),
				Transparency = 0.1,
			}),

			TextLabel({
				Name = "CrateName",
				Size = usePx.udim2(1, 0, 0, 46),
				Position = usePx.udim2(0, 0, 0, 6),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = blockName,
				TextColor3 = WHITE,
				FontFace = BOLD_FONT,
				Stroke = { Thickness = usePx(3) },
				ZIndex = 3,
			}),

			TextLabel({
				Name = "RollCounter",
				Size = usePx.offset(180, 38),
				Position = usePx.udim2(1, -26, 0, 10),
				AnchorPoint = Vector2.new(1, 0),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = function()
					return string.format("%d / %d", rollNumber(), rollCount())
				end,
				Visible = function()
					return rollCount() > 1
				end,
				TextColor3 = Color3.fromRGB(180, 208, 232),
				FontFace = HEAVY_FONT,
				Stroke = { Thickness = usePx(3) },
				ZIndex = 3,
			}),

			revealRays(wonColor, reveal, raysRotation),

			Frame({
				Name = "Reel",
				AnchorPoint = Vector2.new(0.5, 0),
				Size = usePx.udim2(0.95, 0, 0, REEL_HEIGHT),
				Position = usePx.udim2(0.5, 0, 0, REEL_TOP),
				ClipsDescendants = true,

				Vide.action(function(instance: Instance)
					itemsFrameRef = instance
				end),

				Frame({
					Name = "ItemsContainer",
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					AnchorPoint = Vector2.new(0.5, 0.5),

					Vide.action(function(instance: Instance)
						containerRef = instance
					end),

					Vide.create("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = usePx.udim(0, TILE_GAP),
					}),

					Vide.create("UIPadding", {
						PaddingLeft = usePx.udim(0, TILE_GAP),
						PaddingRight = usePx.udim(0, TILE_GAP),
					}),

					Vide.indexes(rollStrip, function(trailId: () -> number, index: number)
						return reelTile(trailId, index, crateId, isRevealed)
					end),
				}),

				edgeFade(0, 0),
				edgeFade(1, 180),

				-- Rarity flash over the reel on reveal.
				Frame({
					Name = "Flash",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = wonColor,
					BackgroundTransparency = flash,
					ZIndex = 7,
				}),
			}),

			reelMarker(markerColor, kick),

			TextLabel({
				Name = "Result",
				Size = usePx.udim2(1, 0, 0, 48),
				Position = function()
					return UDim2.new(0.5, 0, 0, RESULT_TOP_PX() + RESULT_SLIDE_PX() * (1 - reveal()))
				end,
				AnchorPoint = Vector2.new(0.5, 0),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = function()
					local trail = wonTrail()
					if not trail then
						return ""
					end
					return string.format("%s  •  %s  •  x%.2f", trail.trailName, trail.trailRarity, trail.trailMultiplier)
				end,
				Visible = isRevealed,
				TextColor3 = wonColor,
				TextTransparency = function()
					return 1 - reveal()
				end,
				FontFace = HEAVY_FONT,
				Stroke = {
					Thickness = usePx(4),
					Transparency = function()
						return 1 - reveal()
					end,
				},
				ZIndex = 3,
			}),

			StudButton({
				Size = usePx.offset(296, 86),
				Position = usePx.udim2(0.5, 0, 1, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Colors = ButtonColors.Green,
				Visible = function()
					return not isRolling() and #pendingRolls() == 0
				end,
				Text = "Claim",
				OnClick = CratesSlice.actions.closeScreen,
				ZIndex = 10,
			} :: StudButton.StudButton),
		}),
	})
end

return {
	Component = function()
		local isScreenOn = VideCharm.useAtom(CratesSlice.states.cratesScreenOpen)

		Vide.effect(function()
			local screenOn = isScreenOn()

			if screenOn then
				Menu.hideOpenMenu("CratesScreen")
			else
				Menu.restoreOpenMenu("CratesScreen")
			end

			HudSlice.showEverything(not screenOn)
		end)

		return Vide.show(isScreenOn, rollScreen)
	end,
}
