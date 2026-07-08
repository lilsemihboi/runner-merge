local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

type Bindable<T> = T | () -> T -- it supports functions it should return the Type

export type ImageLabelProps = {
	-- ImageLabel-specific
	Image: Bindable<string>?,
	ImageColor3: Bindable<Color3>?,
	-- ImageContent:     Bindable<Content>?,   -- uncomment when Content type is available
	-- ImageRectOffset:  Bindable<Vector2>?,   -- uncomment to enable spritesheet support
	-- ImageRectSize:    Bindable<Vector2>?,   -- uncomment to enable spritesheet support
	ImageTransparency: Bindable<number>?,
	IsLoaded: Bindable<boolean>?,
	ResampleMode: Bindable<Enum.ResamplerMode>?,
	ScaleType: Bindable<Enum.ScaleType>?,
	SliceCenter: Bindable<Rect>?,
	SliceScale: Bindable<number>?,
	TileSize: Bindable<UDim2>?,

	-- GuiObject base
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

	-- Navigation
	NextSelectionDown: GuiObject?,
	NextSelectionLeft: GuiObject?,
	NextSelectionRight: GuiObject?,
	NextSelectionUp: GuiObject?,
	SelectionImageObject: GuiObject?,

	-- Events
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

--- ImageLabel primitive wrapping Vide's `create`.
--- All props support both static values and reactive sources (() -> T).
return function(props: ImageLabelProps): ImageLabel
	return create("ImageLabel")({
		-- ImageLabel properties
		Image = props.Image,
		ImageColor3 = props.ImageColor3,
		ImageTransparency = props.ImageTransparency,
		ResampleMode = props.ResampleMode,
		ScaleType = props.ScaleType,
		SliceCenter = props.SliceCenter,
		SliceScale = props.SliceScale,
		TileSize = props.TileSize,

		-- GuiObject base properties
		Active = props.Active,
		AnchorPoint = props.AnchorPoint,
		AutomaticSize = props.AutomaticSize,
		BackgroundColor3 = props.BackgroundColor3,
		BackgroundTransparency = props.BackgroundTransparency or 1,
		BorderColor3 = props.BorderColor3,
		BorderMode = props.BorderMode,
		BorderSizePixel = props.BorderSizePixel,
		ClipsDescendants = props.ClipsDescendants,
		Interactable = props.Interactable,
		LayoutOrder = props.LayoutOrder,
		Name = props.Name,
		Position = props.Position,
		Rotation = props.Rotation,
		Selectable = props.Selectable,
		SelectionOrder = props.SelectionOrder,
		Size = props.Size,
		SizeConstraint = props.SizeConstraint,
		Visible = props.Visible,
		ZIndex = props.ZIndex,

		-- Object-value properties (not reactive, assigned directly)
		NextSelectionDown = props.NextSelectionDown,
		NextSelectionLeft = props.NextSelectionLeft,
		NextSelectionRight = props.NextSelectionRight,
		NextSelectionUp = props.NextSelectionUp,
		SelectionImageObject = props.SelectionImageObject,

		-- Events
		InputBegan = props.InputBegan,
		InputChanged = props.InputChanged,
		InputEnded = props.InputEnded,
		MouseEnter = props.MouseEnter,
		MouseLeave = props.MouseLeave,
		MouseMoved = props.MouseMoved,
		MouseWheelBackward = props.MouseWheelBackward,
		MouseWheelForward = props.MouseWheelForward,
		SelectionGained = props.SelectionGained,
		SelectionLost = props.SelectionLost,
		TouchLongPress = props.TouchLongPress,
		TouchPan = props.TouchPan,
		TouchPinch = props.TouchPinch,
		TouchRotate = props.TouchRotate,
		TouchSwipe = props.TouchSwipe,
		TouchTap = props.TouchTap,

		-- Children (numeric keys)
		table.unpack(props :: any),
	})
end
