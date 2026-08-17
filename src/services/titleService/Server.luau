--!nonstrict

local TitleService = {}

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local DataService = require(ReplicatedStorage.Packages.DataService)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
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
	local playerJanitors = {}

	local function setTitle(player: Player, titleAtom)
		if not DataService.server:waitForData(player) or player.Parent ~= Players then
			return
		end
		local _, groupTitle = self.getGroupRank(player)
		if player.Parent ~= Players then
			return
		end

		if groupTitle then
			titleAtom(groupTitle)
			return
		end

		if MonetizationServiceServer:ownsGamepass(player, Products.vip) then
			titleAtom("vip")
			return
		end

		playerJanitors[player]:Add(
			MonetizationServiceServer:getPassOwnshipChanged(player, Products.vip):Connect(function(owns)
				if owns then
					titleAtom("vip")
				end
			end),
			"Disconnect"
		)
	end

	local function playerAdded(player)
		if playerTitles[player.UserId] then
			return
		end

		local titleAtom = Charm.atom(nil)
		playerTitles[player.UserId] = titleAtom
		playerJanitors[player] = Janitor.new()

		setTitle(player, titleAtom)
		if player.Parent ~= Players then
			return
		end

		player:SetAttribute("TitleId", titleAtom())

		playerJanitors[player]:Add(Charm.subscribe(titleAtom, function(title)
			if player.Parent == Players then
				player:SetAttribute("TitleId", title)
			end
		end))
	end

	for _, player in Players:GetPlayers() do
		task.spawn(playerAdded, player)
	end
	Players.PlayerAdded:Connect(playerAdded)

	Players.PlayerRemoving:Connect(function(player)
		local janitor = playerJanitors[player]
		if janitor then
			janitor:Destroy()
		end
		playerJanitors[player] = nil
		playerTitles[player.UserId] = nil
	end)
end

type TitleService = typeof(TitleService) & {}

return TitleService :: TitleService
