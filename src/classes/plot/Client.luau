local Plot = {}
Plot.__index = Plot

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotServiceTypes = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceTypes)

function Plot.new(plotData: PlotServiceTypes.PlotData): Plot
	local self = setmetatable({
		plotId = plotData.plotId,
		plotModel = workspace._PLOTS:WaitForChild(tostring(plotData.plotId)),
		player = plotData.player,
		janitor = Janitor.new(),
	}, Plot) :: Plot
	self.networker = Networker.client.new(`plot_{self.player.Name}`, self)

	return self
end

function Plot.destroy(self: Plot): ()
	self.networker:destroy()
	self.janitor:Destroy()
end

export type Plot = typeof(setmetatable(
	{} :: {
		plotId: number,
		plotModel: typeof(workspace._PLOTS["1"]),
		player: Player,
		networker: Networker.Client,
		janitor: Janitor.Janitor,
	},
	Plot
))

return Plot
