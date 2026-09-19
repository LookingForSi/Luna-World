--!strict

local LeaseRules = {}

export type Lease = {
	Token: string,
	ExpiresAt: number,
}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function LeaseRules.isValid(lease: unknown): boolean
	if typeof(lease) ~= "table" then return false end
	local value: any = lease
	return typeof(value.Token) == "string"
		and value.Token ~= ""
		and typeof(value.ExpiresAt) == "number"
		and finite(value.ExpiresAt)
end

function LeaseRules.canClaim(existing: Lease?, requestedToken: string, now: number): boolean
	assert(requestedToken ~= "", "session token must not be empty")
	assert(finite(now), "server time must be finite")
	if existing == nil then return true end
	if existing.Token == requestedToken then return true end
	return existing.ExpiresAt <= now
end

function LeaseRules.isOwner(existing: Lease?, token: string): boolean
	return existing ~= nil and token ~= "" and existing.Token == token
end

function LeaseRules.renew(token: string, now: number, timeoutSeconds: number): Lease
	assert(token ~= "", "session token must not be empty")
	assert(finite(now), "server time must be finite")
	assert(finite(timeoutSeconds) and timeoutSeconds > 0, "lease timeout must be positive")
	return {
		Token = token,
		ExpiresAt = now + timeoutSeconds,
	}
end

return table.freeze(LeaseRules)
