--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileSchema = require(ReplicatedStorage.Shared.persistence.ProfileSchema)
local PersistenceTypes = require(ReplicatedStorage.Shared.types.PersistenceTypes)
local ProfileStoreContract = require(script.Parent.ProfileStoreContract)

local SessionProfileStore = {}
SessionProfileStore.__index = SessionProfileStore

export type Store = typeof(setmetatable({} :: {
	records: { [number]: PersistenceTypes.Profile },
	claims: { [number]: string },
}, SessionProfileStore))

function SessionProfileStore.new(): Store
	return setmetatable({
		records = {},
		claims = {},
	}, SessionProfileStore)
end

function SessionProfileStore:claim(
	userId: number,
	sessionToken: string,
	_now: number
): ProfileStoreContract.ClaimResult
	local owner = self.claims[userId]
	if owner ~= nil and owner ~= sessionToken then
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

function SessionProfileStore:save(
	userId: number,
	sessionToken: string,
	profile: PersistenceTypes.Profile,
	_now: number
): ProfileStoreContract.MutationResult
	if self.claims[userId] ~= sessionToken then
		return { ok = false, reason = "Conflict" }
	end
	local valid = ProfileSchema.validateCurrent(profile)
	if not valid then return { ok = false, reason = "InvalidProfile" } end
	self.records[userId] = ProfileSchema.clone(profile)
	return { ok = true }
end

function SessionProfileStore:release(
	userId: number,
	sessionToken: string,
	profile: PersistenceTypes.Profile,
	now: number
): ProfileStoreContract.MutationResult
	local result = self:save(userId, sessionToken, profile, now)
	if not result.ok then return result end
	self.claims[userId] = nil
	return { ok = true }
end

return SessionProfileStore
