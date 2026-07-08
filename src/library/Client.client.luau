local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local PlotServiceClient = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceClient)
local RunnerManager = require(ReplicatedStorage.Shared.Classes.Runner.RunnerManager)

local DataService = require(ReplicatedStorage.Packages.DataService).client

DataService:init()
PlotServiceClient:init()
RunnerManager.new()
SoundService:WaitForChild("Music"):Play()
