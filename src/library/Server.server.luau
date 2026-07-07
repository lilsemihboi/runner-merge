local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local PlotServiceServer = require(ServerScriptService.Services.PlotService.PlotServiceServer)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RunnerServiceServer = require(ServerScriptService.Services.RunnerService.RunnerServiceServer)

local DataService = require(ReplicatedStorage.Packages.DataService).server

DataService:init({
	resetData = false,
	useMock = false,
	template = DataTemplate,
	profileStoreIndex = RunService:IsStudio() and "__test__" or "__production__",
})

ProfileServiceServer:init()
RunnerServiceServer:init()
PlotServiceServer:init()
