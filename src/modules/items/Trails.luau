return {
	[1] = {
		trailMultiplier = 1.15,
		trailName = "Green",
		trailColorSequence = ColorSequence.new(Color3.fromRGB(60, 255, 0)),
	},

	[2] = {
		trailMultiplier = 1.25,
		trailName = "Black and White",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.275, Color3.fromRGB(13, 13, 13)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
	},
	[3] = {
		trailMultiplier = 1.50,
		trailName = "Rainbow",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 200)),
			ColorSequenceKeypoint.new(0.295, Color3.fromRGB(35, 86, 255)),
			ColorSequenceKeypoint.new(0.442, Color3.fromRGB(77, 244, 244)),
			ColorSequenceKeypoint.new(0.621, Color3.fromRGB(32, 230, 10)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 204, 1)),
		}),
	},
} :: { [number]: { trailMultiplier: number, trailName: string, trailColorSequence: ColorSequence } }
