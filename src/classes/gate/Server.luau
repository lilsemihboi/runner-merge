local Gate = {}
Gate.__index = Gate

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ProfileServer = require(ServerScriptService.Classes.Profile.ProfileServer)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)

local gateTemplate = ReplicatedStorage.Assets.GateV1

function Gate.new(player: Player, plotId: number, gateId: number): Gate
	assert(gateId <= 10, "Gate count cant be bigger than 10")

	local self = setmetatable({
		profile = ProfileServiceServer.getProfile(player),
		gateId = gateId,
		janitor = Janitor.new(),
		plotId = plotId,
	}, Gate) :: Gate

	self:placeGate()

	return self
end

function Gate.placeGate(self: Gate)
	local gateModel = gateTemplate:Clone()
	self.gateModel = gateModel
	self.janitor:Add(gateModel, "Destroy")

	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	if not plotsFolder then
		return
	end

	local plotModel = plotsFolder:FindFirstChild(tostring(self.plotId))
	if not plotModel then
		return
	end

	local runwayModel = plotModel:FindFirstChild("Runway")
	if not runwayModel then
		return
	end

	local gateAttachments = runwayModel:FindFirstChild("gateAttachments")
	if not gateAttachments then
		return
	end

	local attachment = gateAttachments:FindFirstChild(tostring(self.gateId))
	if not attachment or not attachment:IsA("Attachment") then
		return
	end

	gateModel:PivotTo(attachment.WorldCFrame)
	gateModel.Parent = plotModel
end

function Gate.destroy(self: Gate)
	self.janitor:Destroy()
end

export type Gate = typeof(setmetatable(
	{} :: {
		profile: ProfileServer.Profile,
		plotId: number,
		gateId: number,
		gateModel: Model?,
		janitor: Janitor.Janitor,
	},
	Gate
))

return Gate
