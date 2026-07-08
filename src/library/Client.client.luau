local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local AutoRejoinServiceClient = require(ReplicatedStorage.Shared.Services.AutoRejoinService.AutoRejoinServiceClient)
local Feedback = require(ReplicatedStorage.Shared.Modules.Game.Feedback)
local PlotServiceClient = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceClient)
local RunnerManager = require(ReplicatedStorage.Shared.Classes.Runner.RunnerManager)

local DataService = require(ReplicatedStorage.Packages.DataService).client

DataService:init()
PlotServiceClient:init()
RunnerManager.new()
AutoRejoinServiceClient:init()

SoundService:WaitForChild("Music"):Play()
Feedback:init()
