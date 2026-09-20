--!strict
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PersistenceConfig = require(ReplicatedStorage.Shared.config.PersistenceConfig)

local NicknameStore = {}
NicknameStore.__index = NicknameStore
export type Owner = { userId: number, characterId: string }

-- Shared by all players/clients in one Studio server process so multi-client
-- nickname races are still testable without enabling real API services.
local studioIndex: { [string]: Owner } = {}

local function sameOwner(a: Owner?, b: Owner): boolean
	return a ~= nil and a.userId == b.userId and a.characterId == b.characterId
end

function NicknameStore.new(override: any?): any
	if override ~= nil then
		return setmetatable({ store = override, useMemory = false }, NicknameStore)
	end
	local useMemory = RunService:IsStudio() and not PersistenceConfig.UseDataStoreInStudio
	return setmetatable({
		store = if useMemory then nil else DataStoreService:GetDataStore("LunaWorldNicknameIndex_v1"),
		useMemory = useMemory,
	}, NicknameStore)
end

function NicknameStore:check(canonical: string): (boolean, string?)
	if self.useMemory then
		return studioIndex[canonical] == nil, nil
	end
	local ok, value = pcall(function()
		return self.store:GetAsync("nickname:" .. canonical)
	end)
	if not ok then
		return false, "StoreError"
	end
	return value == nil, nil
end

function NicknameStore:reserve(canonical: string, owner: Owner): (boolean, string?)
	if self.useMemory then
		local current = studioIndex[canonical]
		if current == nil or sameOwner(current, owner) then
			studioIndex[canonical] = owner
			return true, nil
		end
		return false, "NicknameTaken"
	end

	local accepted = false
	local ok = pcall(function()
		self.store:UpdateAsync("nickname:" .. canonical, function(current: any)
			if current == nil or (current.userId == owner.userId and current.characterId == owner.characterId) then
				accepted = true
				return owner
			end
			return current
		end)
	end)
	if not ok then
		return false, "StoreError"
	end
	return accepted, if accepted then nil else "NicknameTaken"
end

function NicknameStore:release(canonical: string, owner: Owner): (boolean, string?)
	if self.useMemory then
		local current = studioIndex[canonical]
		if not sameOwner(current, owner) then
			return false, "NotOwner"
		end
		studioIndex[canonical] = nil
		return true, nil
	end

	local released = false
	local ok = pcall(function()
		self.store:UpdateAsync("nickname:" .. canonical, function(current: any)
			if current ~= nil and current.userId == owner.userId and current.characterId == owner.characterId then
				released = true
				return nil
			end
			return current
		end)
	end)
	return ok and released, if ok then (if released then nil else "NotOwner") else "StoreError"
end

return NicknameStore
