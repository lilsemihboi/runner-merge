local _Rarities = require(script.Parent.Rarities)

return {
	-- Common: single muted color, x1.10 - x1.30
	[1] = {
		trailMultiplier = 1.10,
		trailName = "Smoke",
		trailColorSequence = ColorSequence.new(Color3.fromRGB(120, 120, 120)),
		trailRarity = "Common",
	},
	[2] = {
		trailMultiplier = 1.18,
		trailName = "Rust",
		trailColorSequence = ColorSequence.new(Color3.fromRGB(140, 78, 42)),
		trailRarity = "Common",
	},
	[3] = {
		trailMultiplier = 1.25,
		trailName = "Denim",
		trailColorSequence = ColorSequence.new(Color3.fromRGB(72, 96, 140)),
		trailRarity = "Common",
	},
	[4] = {
		trailMultiplier = 1.30,
		trailName = "Green",
		trailColorSequence = ColorSequence.new(Color3.fromRGB(60, 255, 0)),
		trailRarity = "Common",
	},

	-- Rare: two-color gradient, x1.50 - x1.90
	[5] = {
		trailMultiplier = 1.50,
		trailName = "Ocean",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 74, 160)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(94, 214, 235)),
		}),
		trailRarity = "Rare",
	},
	[6] = {
		trailMultiplier = 1.70,
		trailName = "Ember",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 32, 16)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 138, 40)),
		}),
		trailRarity = "Rare",
	},
	[7] = {
		trailMultiplier = 1.90,
		trailName = "Toxic",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 110, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 60)),
		}),
		trailRarity = "Rare",
	},

	-- Epic: three-color gradient, x2.20 - x2.80
	[8] = {
		trailMultiplier = 2.20,
		trailName = "Black and White",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.275, Color3.fromRGB(13, 13, 13)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
		trailRarity = "Epic",
	},
	[9] = {
		trailMultiplier = 2.40,
		trailName = "Amethyst",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 40, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 110, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 190, 255)),
		}),
		trailRarity = "Epic",
	},
	[10] = {
		trailMultiplier = 2.60,
		trailName = "Sunset",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 70)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 120)),
		}),
		trailRarity = "Epic",
	},
	[11] = {
		trailMultiplier = 2.80,
		trailName = "Frostbite",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 130, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 230, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 252, 255)),
		}),
		trailRarity = "Epic",
	},

	-- Legendary: four-color gradient, x3.50 - x4.30
	[12] = {
		trailMultiplier = 3.50,
		trailName = "Golden Hour",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 20)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 215, 80)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 245, 170)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 60)),
		}),
		trailRarity = "Legendary",
	},
	[13] = {
		trailMultiplier = 4.30,
		trailName = "Nebula",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 180)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(150, 80, 255)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(70, 140, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
		}),
		trailRarity = "Legendary",
	},

	-- Mythic: five-color neon gradient, x5.25 - x6.50
	[14] = {
		trailMultiplier = 5.25,
		trailName = "Plasma",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 40, 120)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 120, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 90)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 240, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 90, 255)),
		}),
		trailRarity = "Mythic",
	},
	[15] = {
		trailMultiplier = 6.50,
		trailName = "Aurora",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 255, 190)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(110, 245, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 180, 255)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(220, 140, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 235)),
		}),
		trailRarity = "Mythic",
	},

	-- Secret: six-plus-color gradient, x8.00 - x9.99
	[16] = {
		trailMultiplier = 8.00,
		trailName = "Prismatic",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 230, 100)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(110, 255, 150)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(100, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 120, 255)),
		}),
		trailRarity = "Secret",
	},
	[17] = {
		trailMultiplier = 9.99,
		trailName = "Rainbow",
		trailColorSequence = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 200)),
			ColorSequenceKeypoint.new(0.295, Color3.fromRGB(35, 86, 255)),
			ColorSequenceKeypoint.new(0.442, Color3.fromRGB(77, 244, 244)),
			ColorSequenceKeypoint.new(0.621, Color3.fromRGB(32, 230, 10)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 204, 1)),
		}),
		trailRarity = "Secret",
	},
} :: { [number]: { trailMultiplier: number, trailName: string, trailColorSequence: ColorSequence, trailRarity: keyof<typeof(_Rarities)> } }
