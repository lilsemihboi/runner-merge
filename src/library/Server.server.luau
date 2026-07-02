local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)

local DataService = require(ReplicatedStorage.Packages.DataService).server

DataService:init({
    resetData = false,
    useMock = false,
    template = DataTemplate,
    profileStoreIndex = RunService:IsStudio() and "__test__" or "__production__"
})
