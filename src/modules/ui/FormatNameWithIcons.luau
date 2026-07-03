local trustedPeople = {
	11092812416,
	1684647642,
}

return function(player: Player)
	local icons = ""

	if player.HasVerifiedBadge or table.find(trustedPeople, player.UserId) then
		icons ..= utf8.char(57344) .. " "
	end

	if player.MembershipType == Enum.MembershipType.Premium then
		icons ..= utf8.char(57345) .. " "
	end

	return icons .. player.DisplayName
end
