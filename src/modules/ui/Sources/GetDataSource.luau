local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local DataService = require(ReplicatedStorage.Packages.DataService).client

--[=[
	@param path string | { string } -- The path to the data (top-level key or nested path)
	@param deferred boolean? -- If true, batches rapid updates using task.defer
	@return Charm.Atom -- A reactive atom synchronized with the data
]=]
return function(path: string | { string }, deferred: boolean?)
	-- Fetch initial value from DataService
	local initial = DataService:get(path)

	-- Create reactive atom with cloned table data (or primitive value)
	local atom = Charm.atom(if type(initial) == "table" then table.clone(initial) else initial)

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
			-- Immediate mode: update atom right away with cloned data
			atom(if type(new) == "table" then table.clone(new) else new)
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
			atom(if type(mostRecent) == "table" then table.clone(mostRecent) else mostRecent)
			mostRecent = nil
			thread = nil
		end)
	end

	-- Subscribe to all data changes at this path
	DataService:getChangedSignal(path):Connect(update)

	return atom
end
