local SettingsService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataService = require(ReplicatedStorage.Packages.DataService).client
local Networker = require(ReplicatedStorage.Packages.Networker)
local SettingsServiceUtils = require(script.Parent.SettingsServiceUtils)

local convertPathToSettingPath = SettingsServiceUtils.convertPathToSettingPath

function SettingsService.init(self: SettingsService)
	self.networker = Networker.client.new("SettingsService", self)
end

function SettingsService.set(self: SettingsService, path: string | { string }, value: any): ()
	DataService:set(convertPathToSettingPath(path), value)
	if RunService:IsRunning() then
		self.networker:fire("set", path, value)
	end
end

function SettingsService.get(_self: SettingsService, path: string | { string }): any
	return DataService:get(convertPathToSettingPath(path))
end

function SettingsService.subscribe(_self: SettingsService, path: string | { string }, callback: (any) -> ()): ()
	local value = DataService:get(convertPathToSettingPath(path))
	callback(value)
	DataService:getChangedSignal(convertPathToSettingPath(path)):Connect(function(newValue)
		callback(newValue)
	end)
end

type SettingsService = typeof(SettingsService) & {
	networker: Networker.Client,
}

return SettingsService :: SettingsService
