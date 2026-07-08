local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local AutoRejoinServiceClient = require(ReplicatedStorage.Shared.Services.AutoRejoinService.AutoRejoinServiceClient)
local Feedback = require(ReplicatedStorage.Shared.Modules.Game.Feedback)
local MountUI = require(ReplicatedStorage.Shared.UI.App.MountUI)
local PlotServiceClient = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceClient)
local RunnerManager = require(ReplicatedStorage.Shared.Classes.Runner.RunnerManager)
local SoundServiceClient = require(ReplicatedStorage.Shared.Services.SoundService.SoundServiceClient)
local DataService = require(ReplicatedStorage.Packages.DataService).client

MountUI()

DataService:init()
PlotServiceClient:init()
RunnerManager.new()
AutoRejoinServiceClient:init()
Feedback:init()
SoundServiceClient:init()
SoundService:WaitForChild("Music"):Play()
