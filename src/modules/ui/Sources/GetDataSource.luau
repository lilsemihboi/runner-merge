local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local DataService = require(ReplicatedStorage.Packages.DataService).client

--[=[
	Recursively copies a value so Charm can never keep a reference to a table
	owned by DataService.

	Charm deep-freezes atom values in Studio to catch accidental mutation of
	reactive state. A shallow `table.clone` would leave nested tables (e.g. a
	runner entry inside the `runners` array) shared with the player data, so
	the freeze would also hit the live DataService table and any later nested
	write (`DataService:set({ "runners", index, "phase" })`) would fail with
	"attempt to modify a readonly table". The copy must be deep.
]=]
local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local copy = table.create(#value)
	for key, item in pairs(value) do
		copy[key] = deepCopy(item)
	end

	return copy
end

--[=[
	@param path string | { string } -- The path to the data (top-level key or nested path)
	@param deferred boolean? -- If true, batches rapid updates using task.defer
	@return Charm.Atom -- A reactive atom synchronized with the data
]=]
return function(path: string | { string }, deferred: boolean?)
	-- Fetch initial value from DataService
	local initial = DataService:get(path)

	-- Create reactive atom with deep-copied table data (or primitive value)
	local atom = Charm.atom(deepCopy(initial))

	-- State for deferred update batching
	local mostRecent: any = nil
	local thread: thread? = nil

	--[=[
		Update handler called whenever the data changes.

		In immediate mode: updates the atom instantly.
		In deferred mode: batches updates to avoid excessive re-renders.
		
		@param new any -- The new data value from DataService
	]=]
	local function update(new: any): ()
		if not deferred then
			-- Immediate mode: update atom right away with deep-copied data
			atom(deepCopy(new))
			return
		end

		-- Deferred mode: batch updates to reduce excessive re-renders
		mostRecent = new

		-- If an update is already scheduled, skip (only the latest value will be used)
		if thread then
			return
		end

		-- Schedule update on next defer cycle
		thread = task.defer(function()
			atom(deepCopy(mostRecent))
			mostRecent = nil
			thread = nil
		end)
	end

	-- Subscribe to all data changes at this path
	DataService:getChangedSignal(path):Connect(update)

	return atom
end
