-----------------------------------------------------
-------   ARROW BEAM TUTORIAL HELPER   --------------
-------           @SESOCELL            --------------
-----------------------------------------------------

--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)

local beam = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Tutorial"):WaitForChild("Arrow")

return function()
	local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart")
	local attachmentForRoot: Attachment
	local clonedBeam: Attachment = beam:Clone() :: Attachment

	local janitor = Janitor.new()

	local function setupCharacter(newCharacter)
		rootPart = newCharacter:WaitForChild("HumanoidRootPart")

		if attachmentForRoot then
			attachmentForRoot:Destroy()
			attachmentForRoot = nil
		end

		attachmentForRoot = Instance.new("Attachment")
		attachmentForRoot.Parent = rootPart

		clonedBeam.Attachment0 = attachmentForRoot
	end

	-- initial setup
	setupCharacter(character)

	janitor:Add(Players.LocalPlayer.CharacterAdded:Connect(setupCharacter), "Disconnect")
	janitor:Add(clonedBeam, "Destroy")

	local utils = {}

	function utils.navigateTo(attachment: Attachment?)
		if not attachment then
			clonedBeam.Enabled = false
			return
		end

		clonedBeam.Attachment1 = attachment
		clonedBeam.Parent = workspace
		clonedBeam.Enabled = true
	end

	function utils.kill()
		janitor:Destroy()
	end

	return utils
end
