local function removeKeys<T>(mainTable: T, keysToRemove: { string }): T
	local mutableTable = table.clone(mainTable) :: any

	for _, key in keysToRemove do
		mutableTable[key] = nil
	end

	return mutableTable
end

return removeKeys
