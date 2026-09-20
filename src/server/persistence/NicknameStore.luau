--!strict
local DataStoreService = game:GetService("DataStoreService")
local NicknameStore = {}
NicknameStore.__index = NicknameStore
export type Owner = { userId: number, characterId: string }
function NicknameStore.new(override: any?): any
	return setmetatable(
		{ store = override or DataStoreService:GetDataStore("LunaWorldNicknameIndex_v1") },
		NicknameStore
	)
end
function NicknameStore:check(canonical: string): (boolean, string?)
	local ok, value = pcall(function()
		return self.store:GetAsync("nickname:" .. canonical)
	end)
	if not ok then
		return false, "StoreError"
	end
	return value == nil, nil
end
function NicknameStore:reserve(canonical: string, owner: Owner): (boolean, string?)
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
