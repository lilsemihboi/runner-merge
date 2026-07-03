local Plot = {}
Plot.__index = Plot

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ReplicatedStorage.Packages.DataService).server
local FormatNameWithIcons = require(ReplicatedStorage.Shared.Modules.Ui.FormatNameWithIcons)
local GetPlayerPortaitImage = require(ReplicatedStorage.Shared.Modules.Ui.GetPlayerPortaitImage)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotServiceTypes = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceTypes)
local ProfileServer = require(ServerScriptService.Classes.Profile.ProfileServer)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)

function Plot.new(player: Player, plotId: number): Plot
	local plot = workspace._PLOTS:FindFirstChild(tostring(plotId))
	assert(plot and plot:IsA("Model"), "Plot Not Found!!")
	plot = plot :: Model

	local self: Plot = setmetatable({
		player = player,
		plotId = plotId,
		plotModel = plot,
		janitor = Janitor.new(),
		merge = Plot.merge,
	}, Plot) :: Plot

	local networker = Networker.server.new(`plot_{player.Name}`, self, {
		self.merge,
	})

	self.networker = networker
	self.profile = ProfileServiceServer.getProfile(player)

	self:onCharacterAdded()
	self:setupSign()

	self:watchForAutoMerge()

	return self :: Plot
end

function Plot.setupSign(self: Plot)
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerImage.Image = GetPlayerPortaitImage(self.player.UserId)
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerName.Text = FormatNameWithIcons(self.player) .. "'s Base"
end

function Plot.onCharacterAdded(self: Plot)
	local function teleport()
		local character = self.player.Character or self.player.CharacterAdded:Wait()

		local humanoidRootPart: BasePart = character:WaitForChild("HumanoidRootPart") :: BasePart
		humanoidRootPart.CFrame = self.plotModel.Spawn.WorldCFrame
	end

	teleport()

	self.janitor:Add(self.player.CharacterAdded:Connect(teleport), "Disconnect")
end

function Plot.getPlotData(self: Plot): PlotServiceTypes.PlotData
	return {
		player = self.player,
		plotId = self.plotId,
	}
end

function Plot.destroy(self: Plot)
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerImage.Image = ""
	self.plotModel.Sign.PlayerTable.SurfaceGui.Frame.PlayerName.Text = "Empty"

	self.janitor:Destroy()
	self.networker:destroy()
end

function Plot.merge(self: Plot, player: Player)
	assert(player == self.player, "You dont own the base!")
end

function Plot.addRunner(self: Plot, player: Player, runnerAmount: number)
	if runnerAmount ~= 1 and runnerAmount ~= 5 and runnerAmount ~= 25 and runnerAmount ~= 50 then
		Players:BanAsync({
			UserIds = {
				player.UserId,
			},
			ApplyToUniverse = true,
			Duration = -1,
			DisplayReason = "Your account has been permanently suspended for exploiting or attempting to manipulate the game.",
			PrivateReason = `AUTO[Remote/Method]: Plot.addRunner is exploited; invalid runner amount {runnerAmount} expected 1,5,25 or 50`,
		})
	end
	assert(player == self.player, "You dont own the base!")
	--TODO: Calculate cost

	self.profile:addRunner()
end

function Plot.watchForAutoMerge(self: Plot)
	local function checkCount()
		local runnersAmount = #self.profile:getRunners()

		if runnersAmount >= 20 then
			self:merge(self.player)
		end
	end

	DataService:getArrayInsertedSignal(self.player, { "runners" }):Connect(checkCount)
	DataService:getArrayRemovedSignal(self.player, { "runners" }):Connect(checkCount)
end

export type Plot = typeof(setmetatable(
	{} :: {
		player: Player,
		plotId: number,
		plotModel: typeof(workspace._PLOTS["1"]),
		janitor: Janitor.Janitor,
		networker: Networker.Server,
		profile: ProfileServer.Profile,
	},
	Plot
))

return Plot
