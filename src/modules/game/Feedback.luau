local SocialService = game:GetService("SocialService")
local MailBox = {}

local MailBoxModel = workspace:WaitForChild("Feedback")

function MailBox.init()
	MailBoxModel:WaitForChild("ProximityAttachment"):WaitForChild("Prompt").Triggered:Connect(function()
		SocialService:PromptFeedbackSubmissionAsync()
	end)
end

return MailBox
