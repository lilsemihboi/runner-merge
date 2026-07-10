return function(baseColor: Color3): { Color: ColorSequence, Rotation: number }
	return {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, baseColor),
		}),
		Rotation = 90,
	}
end
