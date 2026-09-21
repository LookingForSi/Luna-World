--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PersistenceConfig = require(ReplicatedStorage.Shared.config.PersistenceConfig)
local MigrationRules = require(ReplicatedStorage.Shared.persistence.MigrationRules)
local AccountSchema = require(ReplicatedStorage.Shared.persistence.AccountSchema)
local PersistenceTypes = require(ReplicatedStorage.Shared.types.PersistenceTypes)
local LeaseRules = require(script.Parent.LeaseRules)
local ProfileStoreContract = require(script.Parent.ProfileStoreContract)

local RobloxProfileStore = {}
RobloxProfileStore.__index = RobloxProfileStore

type Envelope = {
	Profile: any,
	Lease: LeaseRules.Lease?,
}

export type Store = typeof(setmetatable(
	{} :: {
		dataStore: any,
		waitFunction: (number) -> (),
	},
	RobloxProfileStore
))

local function playerKey(userId: number): string
	assert(userId > 0 and userId % 1 == 0, "userId must be a positive integer")
	return "player:" .. tostring(userId)
end

function RobloxProfileStore.resolveStoreName(isStudio: boolean): string
	return PersistenceConfig.DataStoreName .. (if isStudio then PersistenceConfig.StudioStoreSuffix else "")
end

local function unwrap(raw: any): (any, LeaseRules.Lease?, string?)
	if raw == nil then
		return nil, nil, nil
	end
	if typeof(raw) ~= "table" then
		return nil, nil, "stored record must be a table"
	end

	if raw.Profile ~= nil or raw.Lease ~= nil then
		if raw.Profile == nil then
			return nil, nil, "stored envelope has no profile"
		end
		if raw.Lease ~= nil and not LeaseRules.isValid(raw.Lease) then
			return nil, nil, "stored lease is invalid"
		end
		return raw.Profile, raw.Lease, nil
	end

	-- Compatibility for a raw profile written before the lease envelope existed.
	return raw, nil, nil
end

local function loadCanonical(rawProfile: any): (PersistenceTypes.AccountProfile?, string?)
	if rawProfile == nil then
		return AccountSchema.createDefault(), nil
	end
	return MigrationRules.run(rawProfile)
end

function RobloxProfileStore.new(dataStoreOverride: any?, waitFunction: ((number) -> ())?): Store
	local dataStore = dataStoreOverride
	if dataStore == nil then
		dataStore = DataStoreService:GetDataStore(RobloxProfileStore.resolveStoreName(RunService:IsStudio()))
	end
	return setmetatable({
		dataStore = dataStore,
		waitFunction = waitFunction or task.wait,
	}, RobloxProfileStore)
end

function RobloxProfileStore:_updateWithRetry(key: string, transform: (any) -> any): (boolean, any?)
	local lastError: any = nil
	for attempt = 1, PersistenceConfig.MaxAttempts do
		local ok, result = pcall(function()
			return self.dataStore:UpdateAsync(key, transform)
		end)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < PersistenceConfig.MaxAttempts then
			self.waitFunction(PersistenceConfig.RetryBackoffSeconds * attempt)
		end
	end
	return false, lastError
end

function RobloxProfileStore:claim(userId: number, sessionToken: string, now: number): ProfileStoreContract.ClaimResult
	local key = playerKey(userId)
	local claimedProfile: PersistenceTypes.AccountProfile? = nil
	local refusal: ProfileStoreContract.FailureReason? = nil

	local ok = self:_updateWithRetry(key, function(raw: any): any
		refusal = nil
		claimedProfile = nil
		local rawProfile, lease, unwrapError = unwrap(raw)
		if unwrapError ~= nil then
			refusal = "InvalidProfile"
			return nil
		end
		local profile, migrationError = loadCanonical(rawProfile)
		if profile == nil or migrationError ~= nil then
			refusal = "InvalidProfile"
			return nil
		end
		if not LeaseRules.canClaim(lease, sessionToken, now) then
			refusal = "Busy"
			return nil
		end

		claimedProfile = AccountSchema.clone(profile)
		local envelope: Envelope = {
			Profile = AccountSchema.clone(profile),
			Lease = LeaseRules.renew(sessionToken, now, PersistenceConfig.LeaseTimeoutSeconds),
		}
		return envelope
	end)

	if not ok then
		return { ok = false, reason = "StoreError" }
	end
	if refusal ~= nil then
		return { ok = false, reason = refusal }
	end
	if claimedProfile == nil then
		return { ok = false, reason = "StoreError" }
	end
	return { ok = true, profile = claimedProfile }
end

function RobloxProfileStore:save(
	userId: number,
	sessionToken: string,
	profile: PersistenceTypes.AccountProfile,
	now: number
): ProfileStoreContract.MutationResult
	local valid = AccountSchema.validateCurrent(profile)
	if not valid then
		return { ok = false, reason = "InvalidProfile" }
	end
	local key = playerKey(userId)
	local refusal: ProfileStoreContract.FailureReason? = nil

	local ok = self:_updateWithRetry(key, function(raw: any): any
		refusal = nil
		local _, lease, unwrapError = unwrap(raw)
		if unwrapError ~= nil then
			refusal = "InvalidProfile"
			return nil
		end
		if not LeaseRules.isOwner(lease, sessionToken) then
			refusal = "Conflict"
			return nil
		end
		local envelope: Envelope = {
			Profile = AccountSchema.clone(profile),
			Lease = LeaseRules.renew(sessionToken, now, PersistenceConfig.LeaseTimeoutSeconds),
		}
		return envelope
	end)

	if not ok then
		return { ok = false, reason = "StoreError" }
	end
	if refusal ~= nil then
		return { ok = false, reason = refusal }
	end
	return { ok = true }
end

function RobloxProfileStore:release(
	userId: number,
	sessionToken: string,
	profile: PersistenceTypes.AccountProfile,
	_now: number
): ProfileStoreContract.MutationResult
	local valid = AccountSchema.validateCurrent(profile)
	if not valid then
		return { ok = false, reason = "InvalidProfile" }
	end
	local key = playerKey(userId)
	local refusal: ProfileStoreContract.FailureReason? = nil

	local ok = self:_updateWithRetry(key, function(raw: any): any
		refusal = nil
		local _, lease, unwrapError = unwrap(raw)
		if unwrapError ~= nil then
			refusal = "InvalidProfile"
			return nil
		end
		if not LeaseRules.isOwner(lease, sessionToken) then
			refusal = "Conflict"
			return nil
		end
		local envelope: Envelope = {
			Profile = AccountSchema.clone(profile),
			Lease = nil,
		}
		return envelope
	end)

	if not ok then
		return { ok = false, reason = "StoreError" }
	end
	if refusal ~= nil then
		return { ok = false, reason = refusal }
	end
	return { ok = true }
end

return RobloxProfileStore
