local SFXService = {}
local Loops: { [string]: Sound } = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Networker = require(ReplicatedStorage.Packages.Networker)

function SFXService.init(self: SFXService)
	self.networker = Networker.client.new("SFXService", self)
end

function SFXService.play(_self: SFXService, soundId: string, looped: boolean?): ()
	local sound: Sound = SoundService.SFX:FindFirstChild(soundId) :: Sound
	if not sound then
		warn(`Can not find {soundId} in SFX Folder.`)
		return
	end

	-- Sounds are shared instances, so restarting an active loop would cut it off for every caller.
	if Loops[soundId] then
		return
	end

	sound.Looped = looped == true
	sound.TimePosition = 0
	sound:Play()

	if looped then
		Loops[soundId] = sound
	end
	return
end

function SFXService.stop(_self: SFXService, soundId: string): ()
	local sound: Sound = SoundService.SFX:FindFirstChild(soundId) :: Sound
	if not sound then
		warn(`Can not find {soundId} in SFX Folder.`)
		return
	end

	Loops[soundId] = nil
	sound:Stop()
	return
end

type SFXService = typeof(SFXService) & {
	networker: Networker.Client,
}

return SFXService :: SFXService
