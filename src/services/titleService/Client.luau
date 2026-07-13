--!nonstrict

local TitleService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local FormatNameWithIcons = require(ReplicatedStorage.Shared.Modules.Ui.FormatNameWithIcons)
local TitleServiceUtils = require(script.Parent.TitleServiceUtils)

local ChatWindowConfiguration = TextChatService.ChatWindowConfiguration
local colorSequence = ColorSequence.new(Color3.fromRGB(255, 255, 255))

function TitleService.init(_self: TitleService)
	function TextChatService.OnChatWindowAdded(message: TextChatMessage)
		local properties = ChatWindowConfiguration:DeriveNewMessageProperties()
		local textSource = message.TextSource

		if not textSource then
			return
		end

		local UserId = textSource.UserId
		local PlayerByUserId = Players:GetPlayerByUserId(UserId)

		if not PlayerByUserId then
			return
		end

		local titleId = PlayerByUserId:GetAttribute("TitleId") or ""
		local titleInfo = TitleServiceUtils.titles[titleId]
		local tag = not titleInfo and "" or `[{titleInfo.text}]`
		local color = if not titleInfo then colorSequence else titleInfo.colorSequence

		properties.PrefixText = `<font weight="ExtraBold">{tag}</font>`
		properties.Text = `<font weight="ExtraBold">{FormatNameWithIcons(PlayerByUserId)}:</font> {message.Text}`
		properties.PrefixTextProperties = ChatWindowConfiguration:DeriveNewMessageProperties()

		local UIGradient = Instance.new("UIGradient")

		UIGradient.Color = color
		UIGradient.Rotation = not titleInfo and 0 or titleInfo.rotation
		UIGradient.Parent = properties.PrefixTextProperties

		return properties
	end
end

type TitleService = typeof(TitleService) & {}

return TitleService :: TitleService
