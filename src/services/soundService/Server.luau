local SFXService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)

function SFXService.init(self: SFXService)
	self.networker = Networker.server.new("SFXService", self)
end

function SFXService.play(self: SFXService, target: Player | "all" | { Player }, soundId: string, looped: boolean?)
	if (typeof(target) == "Instance" and target:IsA("Player")) or typeof(target) == "table" then
		self.networker:fire(target, "play", soundId, looped)
	else
		self.networker:fireAll("play", soundId, looped)
	end
end

type SFXService = typeof(SFXService) & {
	networker: Networker.Server,
}

return SFXService :: SFXService
