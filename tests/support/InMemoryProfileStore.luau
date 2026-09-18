--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileSchema = require(ReplicatedStorage.Shared.persistence.ProfileSchema)
local ProfileStoreContract = require(ServerScriptService.Server.persistence.ProfileStoreContract)

local InMemoryProfileStore = {}
InMemoryProfileStore.__index = InMemoryProfileStore

export type Store = typeof(setmetatable({} :: {
	records: { [number]: any },
	claims: { [number]: string },
}, InMemoryProfileStore))

function InMemoryProfileStore.new(seed: { [number]: any }?): Store
	return setmetatable({
		records = seed and table.clone(seed) or {},
		claims = {},
	}, InMemoryProfileStore)
end

function InMemoryProfileStore.claim(self: Store, userId: number, sessionToken: string, _now: number): ProfileStoreContract.ClaimResult
	local existing = self.claims[userId]
	if existing ~= nil and existing ~= sessionToken then
		return { ok = false, reason = "Busy" }
	end
	self.claims[userId] = sessionToken
	local profile = self.records[userId]
	if profile == nil then
		profile = ProfileSchema.createDefault()
		self.records[userId] = ProfileSchema.clone(profile)
	end
	return { ok = true, profile = ProfileSchema.clone(profile) }
end

function InMemoryProfileStore.save(self: Store, userId: number, sessionToken: string, profile: any, _now: number): ProfileStoreContract.MutationResult
	if self.claims[userId] ~= sessionToken then
		return { ok = false, reason = "Conflict" }
	end
	local valid = ProfileSchema.validateCurrent(profile)
	if not valid then
		return { ok = false, reason = "InvalidProfile" }
	end
	self.records[userId] = ProfileSchema.clone(profile)
	return { ok = true }
end

function InMemoryProfileStore.release(self: Store, userId: number, sessionToken: string, profile: any, now: number): ProfileStoreContract.MutationResult
	local saved = self:save(userId, sessionToken, profile, now)
	if not saved.ok then return saved end
	self.claims[userId] = nil
	return { ok = true }
end

return InMemoryProfileStore
