--!strict

local FakeDataStore = {}
FakeDataStore.__index = FakeDataStore

export type Store = typeof(setmetatable({} :: {
	values: { [string]: any },
	failuresRemaining: number,
	updateCalls: number,
}, FakeDataStore))

local function clone(value: any): any
	if typeof(value) ~= "table" then return value end
	local result = {}
	for key, child in value do
		result[clone(key)] = clone(child)
	end
	return result
end

function FakeDataStore.new(): Store
	return setmetatable({
		values = {},
		failuresRemaining = 0,
		updateCalls = 0,
	}, FakeDataStore)
end

function FakeDataStore:failNext(count: number): ()
	self.failuresRemaining = count
end

function FakeDataStore:seed(key: string, value: any): ()
	self.values[key] = clone(value)
end

function FakeDataStore:read(key: string): any
	return clone(self.values[key])
end

function FakeDataStore:UpdateAsync(key: string, transform: (any) -> any): any
	self.updateCalls += 1
	if self.failuresRemaining > 0 then
		self.failuresRemaining -= 1
		error("injected data store failure")
	end
	local current = clone(self.values[key])
	local updated = transform(current)
	if updated ~= nil then
		self.values[key] = clone(updated)
	end
	return clone(self.values[key])
end

return FakeDataStore
