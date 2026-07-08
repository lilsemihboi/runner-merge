local SFXService = {}
local Loops = {}

local HttpService = game:GetService("HttpService")
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

	sound.Looped = looped == true
	sound.TimePosition = 0
	sound:Play()

	if looped then
		local loopId = HttpService:GenerateGUID(false)
		Loops[loopId] = sound
		return
	end
	return
end

type SFXService = typeof(SFXService) & {
	networker: Networker.Client,
}

return SFXService :: SFXService
