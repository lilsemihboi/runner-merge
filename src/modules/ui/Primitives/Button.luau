local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoveKeys = require(ReplicatedStorage.Shared.Modules.Utils.RemoveKeys)
local SoundServiceClient = require(ReplicatedStorage.Shared.Services.SoundService.SoundServiceClient)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

type Bindable<T> = T | () -> T

export type ButtonProps = {
	-- Custom button props
	HoverScale: number?,
	OnEnter: (() -> ())?,
	OnLeave: (() -> ())?,
	OnDown: (() -> ())?,
	OnUp: (() -> ())?,

	-- ImageButton
	HoverImage: Bindable<string>?,
	HoverImageContent: Bindable<Content>?,
	Image: Bindable<string>?,
	ImageColor3: Bindable<Color3>?,
	ImageContent: Bindable<Content>?,
	ImageRectOffset: Bindable<Vector2>?,
	ImageRectSize: Bindable<Vector2>?,
	ImageTransparency: Bindable<number>?,
	IsLoaded: Bindable<boolean>?,
	PressedImage: Bindable<string>?,
	PressedImageContent: Bindable<Content>?,
	ResampleMode: Bindable<Enum.ResamplerMode>?,
	ScaleType: Bindable<Enum.ScaleType>?,
	SliceCenter: Bindable<Rect>?,
	SliceScale: Bindable<number>?,
	TileSize: Bindable<UDim2>?,

	-- GuiButton
	AutoButtonColor: Bindable<boolean>?,
	Modal: Bindable<boolean>?,
	Selected: Bindable<boolean>?,
	Style: Bindable<Enum.ButtonStyle>?,

	-- GuiObject
	Active: Bindable<boolean>?,
	AnchorPoint: Bindable<Vector2>?,
	AutomaticSize: Bindable<Enum.AutomaticSize>?,
	BackgroundColor3: Bindable<Color3>?,
	BackgroundTransparency: Bindable<number>?,
	BorderColor3: Bindable<Color3>?,
	BorderMode: Bindable<Enum.BorderMode>?,
	BorderSizePixel: Bindable<number>?,
	ClipsDescendants: Bindable<boolean>?,
	Interactable: Bindable<boolean>?,
	LayoutOrder: Bindable<number>?,
	Name: Bindable<string>?,
	Position: Bindable<UDim2>?,
	Rotation: Bindable<number>?,
	Selectable: Bindable<boolean>?,
	SelectionOrder: Bindable<number>?,
	Size: Bindable<UDim2>?,
	SizeConstraint: Bindable<Enum.SizeConstraint>?,
	Visible: Bindable<boolean>?,
	ZIndex: Bindable<number>?,

	-- Navigation (not reactive)
	NextSelectionDown: GuiObject?,
	NextSelectionLeft: GuiObject?,
	NextSelectionRight: GuiObject?,
	NextSelectionUp: GuiObject?,
	SelectionImageObject: GuiObject?,

	-- Events
	Activated: ((inputObject: InputObject, clickCount: number) -> ())?,
	MouseButton1Click: (() -> ())?,
	MouseButton1Down: ((x: number, y: number) -> ())?,
	MouseButton1Up: ((x: number, y: number) -> ())?,
	MouseButton2Click: (() -> ())?,
	MouseButton2Down: ((x: number, y: number) -> ())?,
	MouseButton2Up: ((x: number, y: number) -> ())?,
	InputBegan: ((input: InputObject) -> ())?,
	InputChanged: ((input: InputObject) -> ())?,
	InputEnded: ((input: InputObject) -> ())?,
	MouseEnter: ((x: number, y: number) -> ())?,
	MouseLeave: ((x: number, y: number) -> ())?,
	MouseMoved: ((x: number, y: number) -> ())?,
	MouseWheelBackward: ((x: number, y: number) -> ())?,
	MouseWheelForward: ((x: number, y: number) -> ())?,
	SelectionGained: (() -> ())?,
	SelectionLost: (() -> ())?,
	TouchLongPress: ((touchPositions: { any }, state: Enum.UserInputState) -> ())?,
	TouchPan: ((touchPositions: { any }, totalTranslation: Vector2, velocity: Vector2, state: Enum.UserInputState) -> ())?,
	TouchPinch: ((touchPositions: { any }, scale: number, velocity: number, state: Enum.UserInputState) -> ())?,
	TouchRotate: ((touchPositions: { any }, rotation: number, velocity: number, state: Enum.UserInputState) -> ())?,
	TouchSwipe: ((swipeDirection: Enum.SwipeDirection, numberOfTouches: number) -> ())?,
	TouchTap: ((touchPositions: { any }) -> ())?,

	-- Children
	[number]: Instance?,
}

local RESERVED_KEYS = {
	"HoverScale",
	"OnEnter",
	"OnLeave",
	"OnDown",
	"OnUp",
}

return function(props: ButtonProps)
	local hoverScale = props.HoverScale or 1.1
	local scale = Vide.source(1)
	local springScale = Vide.spring(scale, 0.2, 0.7)

	local buttonProps = RemoveKeys(props, RESERVED_KEYS) :: any

	local onSelectionGained = buttonProps.SelectionGained :: (() -> ())?
	local onSelectionLost = buttonProps.SelectionLost :: (() -> ())?

	buttonProps.BackgroundTransparency = buttonProps.BackgroundTransparency or 1

	table.insert(
		buttonProps,
		create("UIScale", {
			Scale = springScale,
		})
	)

	function buttonProps.MouseEnter()
		SoundServiceClient:play("uiEnter")
		scale(hoverScale)
		if props.OnEnter then
			props.OnEnter()
		end
	end

	function buttonProps.MouseLeave()
		scale(1)
		if props.OnLeave then
			props.OnLeave()
		end
	end

	function buttonProps.SelectionGained()
		scale(hoverScale)
		if props.OnEnter then
			props.OnEnter()
		end
		if onSelectionGained then
			onSelectionGained()
		end
	end

	function buttonProps.SelectionLost()
		scale(1)
		if props.OnLeave then
			props.OnLeave()
		end
		if onSelectionLost then
			onSelectionLost()
		end
	end

	function buttonProps.MouseButton1Down()
		SoundServiceClient:play("uiClick")
		if props.OnDown then
			props.OnDown()
		end
	end

	function buttonProps.MouseButton1Up()
		if props.OnUp then
			props.OnUp()
		end
	end

	return create("ImageButton", buttonProps)
end
