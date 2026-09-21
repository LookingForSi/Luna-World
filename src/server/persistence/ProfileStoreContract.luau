--!strict

local PersistenceTypes = require(game:GetService("ReplicatedStorage").Shared.types.PersistenceTypes)

local ProfileStoreContract = {}

export type FailureReason = "NotFound" | "Busy" | "Conflict" | "StoreError" | "InvalidProfile"

export type ClaimResult = { ok: true, profile: PersistenceTypes.AccountProfile } | { ok: false, reason: FailureReason }

export type MutationResult = { ok: true } | { ok: false, reason: FailureReason }

export type Store = {
	claim: (self: any, userId: number, sessionToken: string, now: number) -> ClaimResult,
	save: (
		self: any,
		userId: number,
		sessionToken: string,
		profile: PersistenceTypes.AccountProfile,
		now: number
	) -> MutationResult,
	release: (
		self: any,
		userId: number,
		sessionToken: string,
		profile: PersistenceTypes.AccountProfile,
		now: number
	) -> MutationResult,
}

function ProfileStoreContract.assertValid(store: any): ()
	assert(typeof(store) == "table", "profile store must be a table")
	assert(typeof(store.claim) == "function", "profile store must implement claim")
	assert(typeof(store.save) == "function", "profile store must implement save")
	assert(typeof(store.release) == "function", "profile store must implement release")
end

return table.freeze(ProfileStoreContract)
