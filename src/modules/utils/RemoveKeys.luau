local function removeKeys<T>(mainTable: T, keysToRemove: { string }): T
	local mutableTable = mainTable :: any

	for _, key in keysToRemove do
		mutableTable[key] = nil
	end

	return mainTable
end

return removeKeys
