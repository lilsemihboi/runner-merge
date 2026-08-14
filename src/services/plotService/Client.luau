local PlotService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotClient = require(ReplicatedStorage.Shared.Classes.Plot.PlotClient)
local PlotServiceTypes = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceTypes)

function PlotService.init(self: PlotService)
	self.plotInitialized = Instance.new("BindableEvent")
	self.networker = Networker.client.new("PlotService", self)
end

function PlotService.initPlot(self: PlotService, plotData: PlotServiceTypes.PlotData)
	local plot = PlotClient.new(plotData)
	self.plot = plot
	self.plotInitialized:Fire(plot)
end

function PlotService.destroyPlot(self: PlotService)
	if self.plot then
		self.plot:destroy()
	end
end

function PlotService.getPlot(self: PlotService)
	return self.plot
end

function PlotService.waitForPlot(self: PlotService): PlotClient.Plot
	if self.plot then
		return self.plot
	end

	return self.plotInitialized.Event:Wait()
end

type PlotService = typeof(PlotService) & {
	networker: Networker.Client,
	plot: PlotClient.Plot,
	plotInitialized: BindableEvent,
}

return PlotService :: PlotService
