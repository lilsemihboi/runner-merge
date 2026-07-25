local StarterGui = game:GetService("StarterGui")
return function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.ExperienceShop, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end
