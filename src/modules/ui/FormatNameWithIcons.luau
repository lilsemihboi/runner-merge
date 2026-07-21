local trustedPeople = {
	1684647642,
	1899239115,
}

return function(player: Player)
	local icons = ""

	if player.MembershipType == Enum.MembershipType.Premium then
		icons ..= utf8.char(0xE003)
	end

	if player.HasVerifiedBadge or table.find(trustedPeople, player.UserId) then
		icons ..= utf8.char(57344)
	end

	return player.DisplayName .. icons
end
