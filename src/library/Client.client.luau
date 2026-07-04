local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotServiceClient = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceClient)

local DataService = require(ReplicatedStorage.Packages.DataService).client

DataService:init()
PlotServiceClient:init()
