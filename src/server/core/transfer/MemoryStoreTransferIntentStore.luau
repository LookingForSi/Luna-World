--!strict

local MemoryStoreService = game:GetService("MemoryStoreService")

local MAP_NAME = "LunaWorldTransferIntentsV1"

local Store = {}
Store.__index = Store

function Store.new(): any
	return setmetatable({ map = MemoryStoreService:GetHashMap(MAP_NAME) }, Store)
end

function Store:create(intent: any, ttlSeconds: number): (boolean, string?)
	local created = false
	local ok, reason = pcall(function()
		self.map:UpdateAsync(intent.transferId, function(current)
			created = false
			if current ~= nil then
				return current
			end
			created = true
			return intent
		end, ttlSeconds)
	end)
	if not ok then return false, "StoreError:" .. tostring(reason) end
	return created, if created then nil else "Duplicate"
end

function Store:consume(id: string): (any?, string?)
	local consumed = nil
	local ok, reason = pcall(function()
		self.map:UpdateAsync(id, function(current)
			consumed = current
			return nil
		end, 1)
	end)
	if not ok then
		return nil, "StoreError:" .. tostring(reason)
	end
	return consumed, if consumed == nil then "MissingOrConsumed" else nil
end

function Store:remove(id: string): (boolean, string?)
	local ok, reason = pcall(function()
		self.map:RemoveAsync(id)
	end)
	return ok, if ok then nil else "StoreError:" .. tostring(reason)
end

return Store
