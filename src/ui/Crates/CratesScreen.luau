--!nonstrict

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)
const ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
const CratesSlice = require(script.Parent.CratesSlice)
const Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
const HudSlice = require(ReplicatedStorage.Shared.UI.Hud.HudSlice)
const Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
const StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
const TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
const Vide = require(ReplicatedStorage.Packages.Vide)
const VideCharm = require(ReplicatedStorage.Packages.VideCharm)
const ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
const Rarities = require(ReplicatedStorage.Shared.Modules.Items.Rarities)
const Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)
const usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

const STRIP_LENGTH = 50
const WINNER_INDEX = 46
const SPIN_INFO = TweenInfo.new(Blocks.rollTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

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

const function fmtPct(p: number): string
	if p <= 0 then
		return "0%"
	end
	local s
	if p >= 10 then
		s = string.format("%.1f", p)
	elseif p >= 1 then
		s = string.format("%.2f", p)
	else
		s = string.format("%.3f", p)
	end
	if string.find(s, "%.") then
		s = s:gsub("0+$", ""):gsub("%.$", "")
	end
	return s .. "%"
end

const function rollScreen()
	local rollData = VideCharm.useAtom(CratesSlice.states.rollData)
	local isRolling = VideCharm.useAtom(CratesSlice.states.isRolling)
	local rollStrip = Vide.source({})

	local containerRef: Frame? = nil
	local itemsFrameRef: Frame? = nil

	local blockName = Vide.derive(function()
		local rollInfo = rollData()
		if not rollInfo then
			return ""
		end

		return Blocks.getBlock(rollInfo.crateId).blockName
	end)

	Vide.effect(function()
		local rollInfo = rollData()
		if not rollInfo then
			rollStrip({})
			return
		end
		rollStrip(buildStrip(rollInfo.crateId, rollInfo.trailId))
	end)

	Vide.effect(function()
		local rolling = isRolling()
		local strip = rollStrip()

		if not rolling or #strip == 0 then
			return
		end

		-- defer so containerRef/itemsFrameRef are guaranteed assigned by now
		task.defer(function()
			if not containerRef or not itemsFrameRef then
				return
			end

			local container = containerRef :: Frame
			local itemsFrame = itemsFrameRef :: Frame

			task.spawn(function()
				RunService.RenderStepped:Wait()
				RunService.RenderStepped:Wait()

				local winnerTile = container:FindFirstChild("Reel" .. WINNER_INDEX)
				if not winnerTile then
					CratesSlice.actions.finishRolling()
					return
				end

				local frameCenterX = itemsFrame.AbsolutePosition.X + itemsFrame.AbsoluteSize.X * 0.5
				local winnerCenterX = winnerTile.AbsolutePosition.X + winnerTile.AbsoluteSize.X * 0.5
				local targetOffset = frameCenterX - winnerCenterX

				container.Position = UDim2.fromScale(0, 0.5)
				local tween = TweenService:Create(container, SPIN_INFO, {
					Position = UDim2.new(0, targetOffset, 0.5, 0),
				})
				tween.Completed:Connect(function()
					CratesSlice.actions.finishRolling()
				end)
				tween:Play()
			end)
		end)
	end)

	return Frame({
		Size = usePx.offset(1358, 361),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(7, 15, 24),
		BackgroundTransparency = 0.5,

		Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(5, 16, 43),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = usePx(6),
			Transparency = 0.1,
		}),

		-- Crate Name
		TextLabel({
			Size = usePx.udim2(1, 0, 0, 46),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = blockName,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			Stroke = {
				Thickness = usePx(3),
			},
		}),
		-- Container
		Frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = usePx.udim2(0.95, 0, 0, 245),
			Position = UDim2.fromScale(0.5, 0.5),
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
					Padding = usePx.udim(0, 18),
				}),

				Vide.create("UIPadding", {
					PaddingTop = usePx.udim(0, 0),
					PaddingBottom = usePx.udim(0, 0),
					PaddingLeft = usePx.udim(0, 18),
					PaddingRight = usePx.udim(0, 18),
				}),

				Vide.indexes(rollStrip, function(trailId: () -> number, i: number)
					local trail = Trails[trailId()]
					return Frame({
						Name = `Reel{i}`,
						LayoutOrder = i,
						Size = usePx.offset(235, 235),
						BackgroundColor3 = Color3.new(0, 0, 0),
						BackgroundTransparency = 0.5,

						Vide.create("UIStroke", {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							BorderStrokePosition = Enum.BorderStrokePosition.Inner,
							Color = Color3.fromRGB(255, 255, 255),
							LineJoinMode = Enum.LineJoinMode.Miter,
							Thickness = usePx(6),
							Transparency = 0.5,
						}),

						Vide.create("UIStroke", {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							BorderStrokePosition = Enum.BorderStrokePosition.Outer,
							Color = Color3.fromRGB(0, 0, 0),
							LineJoinMode = Enum.LineJoinMode.Round,
							Thickness = usePx(6),
							Transparency = 0.5,
						}),

						TextLabel({
							Size = usePx.udim2(0.9, 0, 0, 42),
							Text = trail.trailName,
							Position = usePx.udim2(0.5, 0, 0, 6),
							AnchorPoint = Vector2.new(0.5, 0),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Stroke = { Thickness = usePx(4) },
							ZIndex = 3,
							TextScaled = true,
							FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
						}),

						ImageLabel({
							Image = "rbxassetid://112932658180628",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.35, 0.40),
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
								Color = trail.trailColorSequence,
								Rotation = 60,
							}),
						}),

						TextLabel({
							Size = usePx.offset(128, 40),
							Text = string.format("x%.2f", trail.trailMultiplier),
							Position = usePx.udim2(0, 154, 0, 146),
							AnchorPoint = Vector2.new(0.5, 0),
							TextColor3 = Color3.fromRGB(255, 255, 255),
							Stroke = { Thickness = usePx(4) },
							ZIndex = 3,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Right,
							FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
						}),

						TextLabel({
							Size = usePx.offset(128, 44),
							Text = function()
								local rollInfo = rollData()
								return fmtPct(Blocks.getOdds(rollInfo.crateId, trailId()))
							end,
							TextColor3 = Rarities[trail.trailRarity],
							Position = usePx.udim2(0, 154, 0, 186),
							AnchorPoint = Vector2.new(0.5, 0),
							Stroke = { Thickness = usePx(4) },
							ZIndex = 3,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Right,
							FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
						}),
					})
				end),
			}),
		}),
		Vide.create("Frame", {
			Name = "Marker",
			Size = usePx.offset(4, 245),
			Position = usePx.udim2(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 53, 97),
		}),
		-- Okay close
		StudButton({
			Size = usePx.offset(296, 86),
			Position = usePx.udim2(0.5, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Colors = ButtonColors.Green,
			Visible = function()
				return not isRolling()
			end,
			Text = "Okay",
			OnClick = function()
				CratesSlice.states.cratesScreenOpen(false)
			end,
		} :: StudButton.StudButton),
	})
end

return {
	Component = function()
		local prevMenu: string | nil
		local firstRun = true

		local isScreenOn = VideCharm.useAtom(CratesSlice.states.cratesScreenOpen)

		Vide.effect(function()
			local screenOn = isScreenOn()

			if screenOn then
				prevMenu = Vide.untrack(Menu.openedMenu)
				Menu.setOpenedMenu(nil)
				HudSlice.showEverything(false)
			elseif not firstRun then
				if prevMenu ~= "OfflineRewards" then
					Menu.setOpenedMenu(prevMenu)
				end
				HudSlice.showEverything(true)
			end

			firstRun = false
		end)
		return Vide.show(function()
			if isScreenOn() then
				return true
			end

			return false
		end, function()
			return rollScreen()
		end)
	end,
}
