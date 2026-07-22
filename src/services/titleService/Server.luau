--!nonstrict

local TitleService = {}

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local DataService = require(ReplicatedStorage.Packages.DataService)
local MonetizationServiceServer = require(ServerScriptService.Services.MonetizationService.MonetizationServiceServer)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local TitleServiceUtils = require(ReplicatedStorage.Shared.Services.TitleService.TitleServiceUtils)

local GROUP_ID = 113923204

function TitleService.getGroupRank(player: Player)
	if not player:IsInGroupAsync(GROUP_ID) then
		return false
	end

	local roles = GroupService:GetRolesInGroupAsync(player.UserId, GROUP_ID)
	local highestRank = 0

	for _, role in ipairs(roles.Roles) do
		if TitleServiceUtils.groupRanks[role.Rank] then
			highestRank = math.max(highestRank, role.Rank)
		end
	end

	if highestRank == 0 then
		return false
	end

	return true, TitleServiceUtils.groupRanks[highestRank]
end

function TitleService.init(self)
	local playerTitles = {}

	local function setTitle(player: Player, titleAtom)
		DataService.server:waitForData(player)
		local _, groupTitle = self.getGroupRank(player)

		if groupTitle then
			titleAtom(groupTitle)
			return
		end

		if MonetizationServiceServer:ownsGamepass(player, Products.vip) then
			titleAtom("vip")
			return
		end

		MonetizationServiceServer:getPassOwnshipChanged(player, Products.vip):Connect(function(owns)
			if owns then
				titleAtom("vip")
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		local titleAtom = Charm.atom(nil)
		playerTitles[player.UserId] = titleAtom

		setTitle(player, titleAtom)

		player:SetAttribute("TitleId", titleAtom())

		Charm.subscribe(titleAtom, function(title)
			player:SetAttribute("TitleId", title)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerTitles[player.UserId] = nil
	end)
end

type TitleService = typeof(TitleService) & {}

return TitleService :: TitleService
