--!strict

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TransferConfig = require(ReplicatedStorage.Shared.config.TransferConfig)

local MISMATCH_ERROR = "TransferIntentMismatch"

local Store = {}
Store.__index = Store

function Store.new(): any
	return setmetatable({ map = MemoryStoreService:GetHashMap(TransferConfig.MemoryStoreMapName) }, Store)
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

function Store:consume(id: string, expected: any?): (any?, string?)
	local consumed = nil
	local ok, reason = pcall(function()
		self.map:UpdateAsync(id, function(current)
			if current == nil then
				return nil
			end
			if expected ~= nil then
				for key, expectedValue in expected do
					if current[key] ~= expectedValue then
						error(MISMATCH_ERROR)
					end
				end
			end
			consumed = current
			return nil
		end, 1)
	end)
	if not ok then
		if string.find(tostring(reason), MISMATCH_ERROR, 1, true) ~= nil then
			return nil, "Mismatch"
		end
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
