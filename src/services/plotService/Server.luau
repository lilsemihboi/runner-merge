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
	self.plots = {}
end

function PlotService.getPlot(self: PlotService, player: Player): Plot?
	return self.plots[player]
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
	if self.plots[player] then
		return
	end

	local plotModel = self:_claimPlot()
	if not plotModel then
		player:Kick("Failed to claim plot!")
		return
	end

	local plotId = tonumber(plotModel.Name) :: number
	local success, plotOrProblem = xpcall(PlotServer.new, debug.traceback, player, plotId)
	if not success then
		self:_releasePlot(plotModel.Name)
		warn(`[PlotService] Failed to create plot {plotModel.Name} for {player.Name}:\n{plotOrProblem}`)
		if player.Parent then
			player:Kick("Failed to initialize plot. Please rejoin.")
		end
		return
	end

	local plot = plotOrProblem :: Plot
	if not player.Parent then
		plot:destroy()
		self:_releasePlot(plotModel.Name)
		return
	end

	playerData.plot = plot
	self.plots[player] = plot

	self.networker:fire(player, "initPlot", plot:getPlotData())
end

function PlotService.playerRemoving(self: PlotService, player: Player, playerData: PlayerData?)
	local plot = self.plots[player] or (playerData and playerData.plot)

	if plot then
		local success, problem = xpcall(plot.destroy, debug.traceback, plot)
		if not success then
			warn(`[PlotService] Failed to destroy plot {plot.plotId} for {player.Name}:\n{problem}`)
		end
		self:_releasePlot(tostring(plot.plotId))
	end
	self.plots[player] = nil
end

type Plot = PlotServer.Plot
type PlayerData = { plot: Plot | nil }
type PlotService = typeof(PlotService) & {
	networker: Networker.Server,
	playerData: ServicePlayerData.ServicePlayerData<PlayerData>,
	claimedPlots: { [string]: boolean },
	plots: { [Player]: Plot },
}

return PlotService :: PlotService
