return {
	titles = {
		vip = {
			rotation = 90,
			text = "VIP",
			colorSequence = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 210)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 70)),
			}),
		},
		tester = {
			rotation = 90,
			text = "TESTER",
			colorSequence = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(211, 255, 170)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 199, 73)),
			}),
		},
		admin = {
			rotation = 90,
			text = "ADMIN",
			colorSequence = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 211, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 0, 199)),
			}),
		},
		developer = {
			rotation = 90,
			text = "DEV",
			colorSequence = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 211)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(199, 0, 80)),
			}),
		},
		owner = {
			rotation = 90,
			text = "OWNER",
			colorSequence = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 248)),
				ColorSequenceKeypoint.new(0.2, Color3.fromRGB(82, 82, 82)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
			}),
		},
	},
	groupRanks = {
		[242] = "tester",
		[243] = "admin",
		[244] = "developer",
		[245] = "owner",
	},
}
