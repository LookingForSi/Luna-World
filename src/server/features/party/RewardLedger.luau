--!strict

local RewardLedger = {}

function RewardLedger.new(maxEntries: number)
	assert(maxEntries > 0 and maxEntries % 1 == 0, "maxEntries must be a positive integer")
	local ids: { [string]: boolean } = {}
	local order: { string } = {}
	return {
		mark = function(_self, entityId: string): boolean
			if ids[entityId] then return false end
			ids[entityId] = true; table.insert(order, entityId)
			if #order > maxEntries then ids[table.remove(order, 1)] = nil end
			return true
		end,
		clear = function()
			table.clear(ids); table.clear(order)
		end,
	}
end

return table.freeze(RewardLedger)
