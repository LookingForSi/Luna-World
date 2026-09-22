--!strict

local Store = {}
Store.__index = Store

function Store.new(clock: (() -> number)?): any
	return setmetatable({ intents = {}, clock = clock or os.time }, Store)
end

function Store:create(intent: any, _ttlSeconds: number?): (boolean, string?)
	if self.intents[intent.transferId] ~= nil then
		return false, "Duplicate"
	end
	self.intents[intent.transferId] = intent
	return true, nil
end

function Store:consume(id: string, expected: any?): (any?, string?)
	local value = self.intents[id]
	if value == nil then
		return nil, "MissingOrConsumed"
	end
	if value.expiresAt <= self.clock() then
		self.intents[id] = nil
		return nil, "Expired"
	end
	if expected ~= nil then
		for key, expectedValue in expected do
			if value[key] ~= expectedValue then
				return nil, "Mismatch"
			end
		end
	end
	self.intents[id] = nil
	return value, nil
end

function Store:remove(id: string): (boolean, string?)
	self.intents[id] = nil
	return true, nil
end

return Store
