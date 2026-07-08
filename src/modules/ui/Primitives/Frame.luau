local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

type Bindable<T> = T | () -> T

export type FrameProps = {
	-- Frame
	Style: Bindable<Enum.FrameStyle>?,

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
	GuiState: Bindable<Enum.GuiState>?,
	InputSink: Bindable<Enum.InputSink>?,
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

	-- Navigation (not reactive, object references)
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

--- Frame primitive wrapping Vide's `create`.
--- All props support both static values and reactive sources (() -> T).
return function(props: FrameProps)
	return create("Frame", {
		Style = props.Style,

		-- GuiObject
		Active = props.Active,
		AnchorPoint = props.AnchorPoint,
		AutomaticSize = props.AutomaticSize,
		BackgroundColor3 = props.BackgroundColor3,
		BackgroundTransparency = props.BackgroundTransparency or 1,
		BorderColor3 = props.BorderColor3,
		BorderMode = props.BorderMode,
		BorderSizePixel = props.BorderSizePixel,
		ClipsDescendants = props.ClipsDescendants,
		GuiState = props.GuiState,
		InputSink = props.InputSink,
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

		-- Navigation
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

		-- Children
		table.unpack(props :: any),
	})
end
