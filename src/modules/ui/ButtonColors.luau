return {
	["Green"] = {
		buttonStroke = Color3.fromRGB(8, 70, 0),
		outsideColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(212, 255, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(87, 255, 78)),
		}),
		insideColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 255, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(29, 218, 0)),
		}),
		textStroke = Color3.fromRGB(6, 48, 0),
	},
	["Blue"] = {
		buttonStroke = Color3.fromRGB(0, 43, 70),
		outsideColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(152, 245, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 229, 255)),
		}),
		insideColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 251, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 174, 255)),
		}),
		textStroke = Color3.fromRGB(0, 27, 39),
	},
	["Red"] = {
		buttonStroke = Color3.fromRGB(65, 7, 7),
		outsideColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 125, 125)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 30, 30)),
		}),
		insideColor = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 30, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(204, 10, 10)),
		}),
		textStroke = Color3.fromRGB(65, 1, 1),
	},
} :: { [string]: {
	buttonStroke: Color3,
	outsideColor: ColorSequence,
	insideColor: ColorSequence,
	textStroke: Color3,
} }
