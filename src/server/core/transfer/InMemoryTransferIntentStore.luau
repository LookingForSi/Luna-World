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

function Store:consume(id: string): (any?, string?)
	local value = self.intents[id]
	if value == nil then
		return nil, "MissingOrConsumed"
	end
	self.intents[id] = nil
	if value.expiresAt <= self.clock() then
		return nil, "Expired"
	end
	return value, nil
end

function Store:remove(id: string): (boolean, string?)
	self.intents[id] = nil
	return true, nil
end

return Store
