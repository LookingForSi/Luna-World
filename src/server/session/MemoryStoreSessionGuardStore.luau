--!strict

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.config.SessionGuardConfig)
local Rules = require(ReplicatedStorage.Shared.session.SessionGuardRules)

local Store = {}
Store.__index = Store

local function key(userId: number): string
	assert(userId > 0 and userId % 1 == 0, "userId must be a positive integer")
	return "user:" .. tostring(userId)
end

function Store.new(mapOverride: any?): any
	return setmetatable({
		map = mapOverride or MemoryStoreService:GetHashMap(Config.MemoryStoreMapName),
	}, Store)
end

function Store:claim(
	userId: number,
	sessionId: string,
	jobId: string,
	placeId: number,
	now: number,
	ttlSeconds: number
): (boolean, string?)
	local claimed = false
	local refusal: string? = nil
	local ok, reason = pcall(function()
		self.map:UpdateAsync(key(userId), function(current)
			claimed = false
			refusal = nil
			local allowed, why = Rules.canClaim(current, sessionId, now)
			if not allowed then
				refusal = why
				return current
			end
			claimed = true
			return Rules.makeRecord(sessionId, jobId, placeId, now, ttlSeconds)
		end, ttlSeconds)
	end)
	if not ok then return false, "StoreError:" .. tostring(reason) end
	return claimed, if claimed then nil else (refusal or "Busy")
end

function Store:renew(
	userId: number,
	sessionId: string,
	jobId: string,
	placeId: number,
	now: number,
	ttlSeconds: number
): (boolean, string?)
	local renewed = false
	local refusal: string? = nil
	local ok, reason = pcall(function()
		self.map:UpdateAsync(key(userId), function(current)
			renewed = false
			refusal = nil
			if current == nil then
				refusal = "Missing"
				return nil
			end
			if not Rules.isRecord(current) then
				refusal = "InvalidRecord"
				return current
			end
			if current.sessionId ~= sessionId then
				refusal = "Busy"
				return current
			end
			if current.jobId ~= jobId then
				refusal = "Moved"
				return current
			end
			renewed = true
			return Rules.makeRecord(sessionId, jobId, placeId, now, ttlSeconds)
		end, ttlSeconds)
	end)
	if not ok then return false, "StoreError:" .. tostring(reason) end
	return renewed, if renewed then nil else (refusal or "Lost")
end

function Store:release(userId: number, sessionId: string, jobId: string): (boolean, string?)
	local released = false
	local refusal: string? = nil
	local ok, reason = pcall(function()
		self.map:UpdateAsync(key(userId), function(current)
			released = false
			refusal = nil
			if current == nil then
				released = true
				return nil
			end
			if not Rules.isRecord(current) then
				refusal = "InvalidRecord"
				return current
			end
			if current.sessionId ~= sessionId then
				refusal = "Busy"
				return current
			end
			if current.jobId ~= jobId then
				refusal = "Moved"
				return current
			end
			released = true
			return nil
		end, 1)
	end)
	if not ok then return false, "StoreError:" .. tostring(reason) end
	return released, if released then nil else refusal
end

return Store
