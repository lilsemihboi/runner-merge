local PlotService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotServer = require(ServerScriptService.Classes.Plot.PlotServer)
local ServicePlayerData = require(ReplicatedStorage.Packages.ServicePlayerData)

local PLAYER_DATA_TEMPLATE = {
	plot = nil,
}

function PlotService.init(self: PlotService)
	self.networker = Networker.server.new("PlotService", self)
	self.playerData = ServicePlayerData.new(PLAYER_DATA_TEMPLATE :: PlayerData, self)
	self.claimedPlots = {}
end

function PlotService.getPlot(self: PlotService, player: Player): Plot?
	local data = self.playerData:get(player)
	return data and data.plot
end

function PlotService._claimPlot(self: PlotService): Model?
	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	if not plotsFolder then
		return nil
	end

	for _, plotModel in ipairs(plotsFolder:GetChildren()) do
		if plotModel:IsA("Model") and not self.claimedPlots[plotModel.Name] then
			self.claimedPlots[plotModel.Name] = true
			return plotModel
		end
	end

	return nil
end

function PlotService._releasePlot(self: PlotService, plotId: string)
	self.claimedPlots[plotId] = nil
end

function PlotService.playerAdded(self: PlotService, player: Player, playerData: PlayerData)
	local plotModel = self:_claimPlot()
	if not plotModel then
		player:Kick("Failed to claim plot!")
		return
	end

	local plotId = tonumber(plotModel.Name) :: number
	local plot = PlotServer.new(player, plotId)
	playerData.plot = plot

	self.networker:fire(player, "initPlot", plot:getPlotData())
end

function PlotService.playerRemoving(self: PlotService, player: Player, playerData: PlayerData)
	local plot = playerData.plot

	if plot then
		plot:destroy()
		self:_releasePlot(tostring(plot.plotId))
	end
	self.networker:fire(player, "destroyPlot")
end

type Plot = PlotServer.Plot
type PlayerData = { plot: Plot | nil }
type PlotService = typeof(PlotService) & {
	networker: Networker.Server,
	playerData: ServicePlayerData.ServicePlayerData<PlayerData>,
	claimedPlots: { [string]: boolean },
}

return PlotService :: PlotService
