local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

export type Roll = { crateId: number, trailId: number }

const rollData: Charm.Atom<Roll> = Charm.atom({}) :: Charm.Atom<Roll>
const cratesScreenOpen: Charm.Atom<boolean> = Charm.atom(false)
const isRolling: Charm.Atom<boolean> = Charm.atom(false)
-- Rolls still waiting for their turn on the reel. A x3 crate purchase queues three,
-- and the reel plays them back to back without closing the screen in between.
const pendingRolls: Charm.Atom<{ Roll }> = Charm.atom({} :: { Roll })
const rollNumber: Charm.Atom<number> = Charm.atom(1)
const rollCount: Charm.Atom<number> = Charm.atom(1)

--[=[
	Opens the crate screen and starts the first roll. Every roll is decided by the
	server before this is called, so the reel only ever replays a known outcome.
]=]
const function startRolls(rolls: { Roll }): ()
	if #rolls == 0 then
		return
	end

	local queued = table.clone(rolls)
	local firstRoll = table.remove(queued, 1) :: Roll

	Charm.batch(function()
		rollData(firstRoll)
		pendingRolls(queued)
		rollNumber(1)
		rollCount(#rolls)
		cratesScreenOpen(true)
		isRolling(true)
	end)
	return
end

--[=[
	Moves the reel onto the next queued roll. A no-op once the queue drains, which
	leaves the final reveal on screen until the player claims it.
]=]
const function advanceRoll(): ()
	local queued = table.clone(pendingRolls())
	local nextRoll = table.remove(queued, 1)

	if not nextRoll then
		return
	end

	Charm.batch(function()
		rollData(nextRoll)
		pendingRolls(queued)
		rollNumber(rollNumber() + 1)
		isRolling(true)
	end)
	return
end

const function closeScreen(): ()
	Charm.batch(function()
		cratesScreenOpen(false)
		isRolling(false)
		pendingRolls({})
		rollNumber(1)
		rollCount(1)
	end)
	return
end

return {
	actions = {
		beginRolling = function(newData: Roll)
			startRolls({ newData })
		end,

		beginRollQueue = function(rolls: { Roll })
			startRolls(rolls)
		end,
		advanceRoll = advanceRoll,
		closeScreen = closeScreen,

		finishRolling = function()
			isRolling(false)
		end,
	},
	states = {
		rollData = rollData,
		cratesScreenOpen = cratesScreenOpen,
		isRolling = isRolling,
		pendingRolls = pendingRolls,
		rollNumber = rollNumber,
		rollCount = rollCount,
	},
}
