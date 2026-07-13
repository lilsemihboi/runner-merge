local TitleService = {}

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleServiceUtils = require(ReplicatedStorage.Shared.Services.TitleService.TitleServiceUtils)

local GROUP_ID = 113923204

function TitleService.init(_self: TitleService)
	Players.PlayerAdded:Connect(function(player: Player)
		if not player:IsInGroupAsync(GROUP_ID) then
			return
		end
		local roles = GroupService:GetRolesInGroupAsync(player.UserId, GROUP_ID)
		local highestAvailableRank = 0

		for _, role: { Id: number, Name: string, Rank: number } in ipairs(roles.Roles) do
			if TitleServiceUtils.groupRanks[role.Rank] then
				if role.Rank > highestAvailableRank then
					highestAvailableRank = role.Rank
				end
			end
		end

		local titleId = TitleServiceUtils.groupRanks[highestAvailableRank]
		player:SetAttribute("TitleId", titleId)
	end)
end

type TitleService = typeof(TitleService) & {}

return TitleService :: TitleService
