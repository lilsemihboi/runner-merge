const ReplicatedStorage = game:GetService("ReplicatedStorage")
const SoundService = game:GetService("SoundService")

const Charm = require(ReplicatedStorage.Packages.Charm)
const GetDataSource = require(ReplicatedStorage.Shared.Modules.Ui.Sources.GetDataSource)

const SoundServiceClient = require(script.Parent.SoundServiceClient)

const ENGINE_SOUND_ID = "carEngineRunning"

return function()
	const runnersSource = GetDataSource("runners")
	local isEngineRunning = false
			print("HAS CAR")
			print("HAS CAR")

	const function sync(runners: { number })
		const hasCar = #runners > 0

		-- Merges rewrite the array without changing whether a car exists, so only act on transitions.
		if hasCar == isEngineRunning then
			return
		end

		isEngineRunning = hasCar

		if hasCar then
			print("HAS CAR")
			SoundServiceClient:play(ENGINE_SOUND_ID, true)
			return
		end

		SoundServiceClient:stop(ENGINE_SOUND_ID)
	end

	sync(runnersSource())
	Charm.subscribe(runnersSource, sync)
end
