--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

type Bindable<T> = T | () -> T

--- Props for the auto-created UIStroke child.
export type StrokeProps = {
	Color: Bindable<Color3>?,
	Enabled: Bindable<boolean>?,
	LineJoinMode: Bindable<Enum.LineJoinMode>?,
	ApplyStrokeMode: Bindable<Enum.ApplyStrokeMode>?,
	Thickness: Bindable<number>?,
	Transparency: Bindable<number>?,
}

--- Props for the auto-created UIGradient child.
export type GradientProps = {
	Color: Bindable<ColorSequence>?,
	Enabled: Bindable<boolean>?,
	Offset: Bindable<Vector2>?,
	Rotation: Bindable<number>?,
	Transparency: Bindable<NumberSequence>?,
}

--- Props for the optional prefix ImageLabel child.
export type PrefixProps = {
	Image: Bindable<string>?,
	Size: Bindable<UDim2>?,
	HorizontalAlignment: Bindable<Enum.HorizontalAlignment>?,
	VerticalAlignment: Bindable<Enum.VerticalAlignment>?,
	Padding: Bindable<UDim>?,
	SizeConstraint: Bindable<Enum.SizeConstraint>?,
	ImageColor3: Bindable<Color3>?,
	ImageTransparency: Bindable<number>?,
}

--- Props for the auto-created drop shadow TextLabel child.
export type DropShadowProps = {
	Color: Color3?,
	Transparency: number?,
	Offset: UDim2?,
}

local DEFAULT_SHADOW: DropShadowProps = {
	Color = Color3.fromRGB(0, 0, 0),
	Transparency = 0.5,
	Offset = UDim2.fromOffset(2, 2),
}

export type TextLabelProps = {
	-- TextLabel-specific
	Font: Bindable<Enum.Font>?,
	FontFace: Bindable<Font>?,
	LineHeight: Bindable<number>?,
	MaxVisibleGraphemes: Bindable<number>?,
	OpenTypeFeatures: Bindable<string>?,
	RichText: Bindable<boolean>?,
	Text: Bindable<string>?,
	TextColor3: Bindable<Color3>?,
	TextDirection: Bindable<Enum.TextDirection>?,
	TextScaled: Bindable<boolean>?,
	TextSize: Bindable<number>?,
	TextStrokeColor3: Bindable<Color3>?,
	TextStrokeTransparency: Bindable<number>?,
	TextTransparency: Bindable<number>?,
	TextTruncate: Bindable<Enum.TextTruncate>?,
	TextWrapped: Bindable<boolean>?,
	TextXAlignment: Bindable<Enum.TextXAlignment>?,
	TextYAlignment: Bindable<Enum.TextYAlignment>?,

	-- Shorthand children
	Stroke: StrokeProps?,
	Gradient: GradientProps?,
	DropShadow: DropShadowProps?,
	Prefix: PrefixProps?,

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

local function buildStroke(strokeProps: StrokeProps)
	return create("UIStroke", {
		Color = strokeProps.Color,
		Enabled = strokeProps.Enabled,
		LineJoinMode = strokeProps.LineJoinMode,
		ApplyStrokeMode = strokeProps.ApplyStrokeMode,
		Thickness = strokeProps.Thickness,
		Transparency = strokeProps.Transparency,
	})
end

local function buildGradient(gradientProps: GradientProps)
	return create("UIGradient", {
		Color = gradientProps.Color,
		Enabled = gradientProps.Enabled,
		Offset = gradientProps.Offset,
		Rotation = gradientProps.Rotation,
		Transparency = gradientProps.Transparency,
	})
end

local function buildDropShadow(props: TextLabelProps, shadowProps: DropShadowProps)
	return create("TextLabel", {
		Name = "DropShadow",
		BackgroundTransparency = 1,
		ZIndex = (props.ZIndex or 1),
		Text = props.Text,
		TextColor3 = shadowProps.Color or DEFAULT_SHADOW.Color,
		TextSize = props.TextSize,
		TextScaled = (not props.TextSize and (props.TextScaled or false)) or true,
		Font = if props.FontFace then nil else (props.Font or Enum.Font.BuilderSansExtraBold),
		FontFace = props.FontFace,
		TextTransparency = shadowProps.Transparency or DEFAULT_SHADOW.Transparency,
		TextXAlignment = props.TextXAlignment,
		TextYAlignment = props.TextYAlignment,
		TextWrapped = props.TextWrapped,
		Position = (shadowProps.Offset or DEFAULT_SHADOW.Offset) + UDim2.fromScale(-0.025, 0.0125),
		RichText = props.RichText,
		Size = UDim2.fromScale(1, 1),
		table.unpack(shadowProps),
	})
end

--- TextLabel primitive wrapping Vide's `create`.
--- All props support both static values and reactive sources (() -> T).
---
--- Shorthand sugar:
---   `Stroke = {}`                 → auto-creates a UIStroke child
---   `Gradient = {}`               → auto-creates a UIGradient child
---   `DropShadow = {}`             → auto-creates a shadow TextLabel behind the text
---   `DropShadow = { Offset = UDim2.fromOffset(3, 3) }` → custom shadow offset
return function(props: TextLabelProps)
	local textChildren = {}

	if props.Stroke then
		table.insert(textChildren, buildStroke(props.Stroke))
	end

	if props.Gradient then
		table.insert(textChildren, buildGradient(props.Gradient))
	end

	for _, child in ipairs(props :: any) do
		table.insert(textChildren, child)
	end

	local frameChildren = {}

	if props.DropShadow then
		table.insert(frameChildren, buildDropShadow(props, props.DropShadow))
	end

	if props.Prefix then
		table.insert(
			frameChildren,
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = props.Prefix.HorizontalAlignment or Enum.HorizontalAlignment.Center,
				VerticalAlignment = props.Prefix.VerticalAlignment or Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = props.Prefix.Padding or UDim.new(0, 4),
			})
		)

		table.insert(
			frameChildren,
			create("ImageLabel", {
				Name = "Prefix",
				BackgroundTransparency = 1,
				Size = props.Prefix.Size or UDim2.fromScale(1, 1),
				SizeConstraint = props.Prefix.SizeConstraint or Enum.SizeConstraint.RelativeYY,
				LayoutOrder = 0,
				ScaleType = Enum.ScaleType.Fit,
				Image = props.Prefix.Image,
				ImageColor3 = props.Prefix.ImageColor3,
				ImageTransparency = props.Prefix.ImageTransparency,
			})
		)
	end

	table.insert(
		frameChildren,
		create("TextLabel", {
			Font = props.Font,
			FontFace = props.FontFace,
			LineHeight = props.LineHeight,
			MaxVisibleGraphemes = props.MaxVisibleGraphemes,
			OpenTypeFeatures = props.OpenTypeFeatures,
			RichText = props.RichText,
			Text = props.Text,
			TextColor3 = props.TextColor3,
			TextDirection = props.TextDirection,
			TextScaled = props.TextScaled,
			TextSize = props.TextSize,
			TextStrokeColor3 = props.TextStrokeColor3,
			TextStrokeTransparency = props.TextStrokeTransparency,
			TextTransparency = props.TextTransparency,
			TextTruncate = props.TextTruncate,
			TextWrapped = props.TextWrapped,
			TextXAlignment = props.TextXAlignment,
			TextYAlignment = props.TextYAlignment,

			BackgroundTransparency = props.BackgroundTransparency or 1,
			BackgroundColor3 = props.BackgroundColor3,

			AutomaticSize = if props.Prefix then Enum.AutomaticSize.X else nil,
			Size = if props.Prefix then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = (props.ZIndex or 1) + 1,

			table.unpack(textChildren),
		})
	)

	return create("Frame", {
		Name = props.Name,
		Active = props.Active,
		AnchorPoint = props.AnchorPoint,
		AutomaticSize = props.AutomaticSize,
		BackgroundColor3 = props.BackgroundColor3,
		BackgroundTransparency = 1,
		BorderColor3 = props.BorderColor3,
		BorderMode = props.BorderMode,
		BorderSizePixel = props.BorderSizePixel,
		ClipsDescendants = props.ClipsDescendants,
		Interactable = props.Interactable,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Rotation = props.Rotation,
		Selectable = props.Selectable,
		SelectionOrder = props.SelectionOrder,
		Size = props.Size,
		SizeConstraint = props.SizeConstraint,
		Visible = props.Visible,
		ZIndex = props.ZIndex,

		table.unpack(frameChildren),
	})
end
