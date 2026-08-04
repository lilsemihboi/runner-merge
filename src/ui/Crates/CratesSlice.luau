local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

const rollData: Charm.Atom<{ crateId: number, trailId: number }> = Charm.atom({}) :: Charm.Atom<{ crateId: number, trailId: number }>
const cratesScreenOpen: Charm.Atom<boolean> = Charm.atom(false)
const isRolling: Charm.Atom<boolean> = Charm.atom(false)

return {
	actions = {
		beginRolling = function(newData: { crateId: number, trailId: number })
			Charm.batch(function()
				rollData(newData)
				cratesScreenOpen(true)
				isRolling(true)
			end)
		end,

		finishRolling = function()
			isRolling(false)
		end,
	},
	states = {
		rollData = rollData,
		cratesScreenOpen = cratesScreenOpen,
		isRolling = isRolling,
	},
}
