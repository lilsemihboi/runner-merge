local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotServiceClient = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceClient)
local RunnerManager = require(ReplicatedStorage.Shared.Classes.Runner.RunnerManager)

local DataService = require(ReplicatedStorage.Packages.DataService).client

DataService:init()
PlotServiceClient:init()

local _runnerManager = RunnerManager.new()
