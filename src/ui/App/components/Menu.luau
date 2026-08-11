--!nonstrict

local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AnalyticsServiceClient = require(ReplicatedStorage.Shared.Services.AnalyticsService.AnalyticsServiceClient)
local ButtonColors = require(ReplicatedStorage.Shared.Modules.Ui.ButtonColors)
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local ImageLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.ImageLabel)
local RemoveKeys = require(ReplicatedStorage.Shared.Modules.Utils.RemoveKeys)
local StudButton = require(ReplicatedStorage.Shared.UI.App.Components.StudButton)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local Vide = require(ReplicatedStorage.Packages.Vide)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local CUSTOM_PROPS = {
	"Title",
	"menuId",
	"ShowTitle",
	"ShowCloseButton",
	"OnClose",
	"Scale",
}
local CLOSE_RENDER_DURATION = 0.5
local SHOP_MENU_ID = "Shop"
local openedMenuSource = Vide.source(nil)
local hideReasonsSource = Vide.source({})
local hasPromptedFavorite = false

local activeCloseFn
local activeMenuId

export type MenuOpenOptions = {
	isRestoringPreviousMenu: boolean?,
}

--[[
	Overlays (purchase prompts, cutscenes, the Roblox menu) need the open menu
	out of the way, but they must not *close* it. Closing is a player intent
	that menus are allowed to act on -- OfflineRewards claims its reward when it
	stops being the open menu -- so an overlay that closed and reopened the menu
	would fire that intent twice and lose the reward.

	Hiding keeps `openedMenu` pointing at the same menu and only suppresses its
	rendering, so nothing observing the open menu sees a change.

	Reasons are counted by key so overlapping overlays can hide independently;
	the menu comes back once the last one restores.
]]
local function isMenuHidden(): boolean
	return next(hideReasonsSource()) ~= nil
end

-- Both writers read the current reasons untracked: they are called from inside
-- the overlays' own effects, and a tracked read would make those effects depend
-- on a source they write to.
local function hideOpenMenu(reason: string)
	local reasons = Vide.untrack(hideReasonsSource)

	if reasons[reason] then
		return
	end

	local nextReasons = table.clone(reasons)
	nextReasons[reason] = true

	hideReasonsSource(nextReasons)
end

local function restoreOpenMenu(reason: string)
	local reasons = Vide.untrack(hideReasonsSource)

	if not reasons[reason] then
		return
	end

	local nextReasons = table.clone(reasons)
	nextReasons[reason] = nil

	hideReasonsSource(nextReasons)
end

export type MenuProps = Frame.FrameProps & {
	Title: string,
	menuId: string,
	ShowTitle: boolean?,
	ShowCloseButton: boolean?,
	OnClose: (() -> any)?,
	Scale: number?,
}

return {
	Component = function(props: MenuProps)
		local isShown = Vide.derive(function()
			return openedMenuSource() == props.menuId and not isMenuHidden()
		end)
		local isRendered = Vide.source(false)
		local isOpen = Vide.source(false)

		local menuScaleTarget = Vide.derive(function()
			return if isOpen() then 1 else 0
		end)
		local menuScale = Vide.spring(menuScaleTarget, 0.35, 0.8)

		Vide.effect(function()
			if isShown() then
				isRendered(true)
				isOpen(false)
				Vide.cleanup(task.defer(isOpen, true))
				return
			end

			isOpen(false)
			Vide.cleanup(task.delay(CLOSE_RENDER_DURATION, isRendered, false))
		end)

		local function closeMenu()
			if props.OnClose then
				props.OnClose()

				return
			end

			if openedMenuSource() == props.menuId then
				openedMenuSource(nil)
			end
		end

		local frameProps = RemoveKeys(props, CUSTOM_PROPS)

		if not props.ShowTitle then
			props.ShowTitle = true
		end

		if not props.Scale then
			props.Scale = 1
		end

		if not props.ShowCloseButton then
			props.ShowCloseButton = true
		end

		frameProps.Visible = isRendered
		frameProps.Size = usePx.offset(1008 * props.Scale, 802 * props.Scale)
		frameProps.AnchorPoint = Vector2.new(0.5, 0.5)
		frameProps.Position = frameProps.Position or UDim2.fromScale(0.5, 0.5)
		frameProps.Name = props.menuId
		frameProps.BackgroundColor3 = Color3.fromRGB(7, 15, 24)
		frameProps.BackgroundTransparency = 0.5

		table.insert(
			frameProps,
			Vide.create("UIScale", {
				Scale = menuScale,
			})
		)
		--6px stroke

		local stroke = Vide.create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(5, 16, 43),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = usePx(6),
			Transparency = 0.1,
		})

		local topFrame = Frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 89, 166),
			BackgroundTransparency = 0,
			Size = usePx.offset(1008 * props.Scale, 116 * props.Scale),
			Position = usePx.udim2(0.5, 0, 0.072, 0),

			Frame({
				Color = Color3.fromRGB(255, 255, 255),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.454),
				Size = UDim2.fromScale(1, 0.908),

				Vide.create("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(171, 255, 252)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 179, 255)),
					}),
					Rotation = 90,
				}),

				StudButton({
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutoButtonColor = false,
					Visible = props.ShowCloseButton,
					Colors = ButtonColors.Red,
					Text = "X",
					Position = UDim2.fromScale(0.948, 0.512),
					Size = usePx.offset(65 * props.Scale, 65 * props.Scale),
					OnClick = closeMenu,
					ZIndex = 100,
				} :: StudButton.StudButton),

				ImageLabel({
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.99, 0.91),
					Image = "rbxassetid://10509779001",
					ScaleType = Enum.ScaleType.Tile,
					TileSize = UDim2.fromScale(0.025, 0.315),

					Vide.create("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 229, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 139, 214)),
						}),
						Rotation = 90,
					}),
				}),

				--Title

				TextLabel({
					Name = "Title",
					ZIndex = 99,
					Visible = props.ShowTitle,
					Text = props.Title:upper(),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					FontFace = Font.new("rbxassetid://11702779517", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					Size = UDim2.fromScale(0.425, 0.703),
					TextScaled = true,
					Position = UDim2.fromScale(0.250, 0.5),

					Stroke = {
						Color = Color3.fromRGB(0, 0, 0),
						Thickness = usePx(4),
					},
				}),
			}),

			Vide.create("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(5, 16, 43),
				Thickness = usePx(4),
				Transparency = 0.1,
			}),
		})

		Vide.effect(function()
			if not isShown() then
				return
			end

			activeCloseFn = closeMenu
			activeMenuId = props.menuId
			Vide.cleanup(function()
				if activeCloseFn == closeMenu then
					activeCloseFn = nil
					activeMenuId = nil
				end
			end)
		end)

		table.insert(frameProps, stroke)
		table.insert(frameProps, topFrame)

		return Frame(frameProps)
	end,

	openedMenu = openedMenuSource,
	--[[
		Opens a menu, or closes it when it is already the open one.

		`options.isRestoringPreviousMenu` marks an open that is putting back UI
		state the game itself took away, rather than one the player asked for,
		so analytics can tell it apart from a real store visit. Overlays no
		longer need it -- they hide the menu instead of closing and reopening
		it -- but it stays supported for any future caller that genuinely has
		to reopen a menu on the player's behalf.

		`options` is tolerated rather than trusted: callers have passed a stale
		positional argument here.
	]]
	setOpenedMenu = function(menuId: string?, options: MenuOpenOptions?)
		local current = Vide.untrack(openedMenuSource)

		if menuId == current then
			openedMenuSource(nil)
			return
		end

		openedMenuSource(menuId)

		if menuId == SHOP_MENU_ID then
			local isRestoring = type(options) == "table" and options.isRestoringPreviousMenu == true

			AnalyticsServiceClient:logStoreOpened(if isRestoring then AnalyticsServiceClient.storeSources.restore else AnalyticsServiceClient.storeSources.menu)
		end

		if menuId == "GroupRewards" and RunService:IsRunning() and not hasPromptedFavorite then
			hasPromptedFavorite = true
			pcall(function()
				AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
			end)
		end
	end,
	closeCurrentMenu = function()
		if activeCloseFn ~= nil and activeMenuId == openedMenuSource() then
			activeCloseFn()

			return
		end

		if openedMenuSource() ~= nil then
			openedMenuSource(nil)
		end
	end,
	hideOpenMenu = hideOpenMenu,
	restoreOpenMenu = restoreOpenMenu,
}
