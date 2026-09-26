--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.config.SessionGuardConfig)

local Rules = {}

export type SessionRecord = {
	version: number,
	sessionId: string,
	jobId: string,
	placeId: number,
	refreshedAt: number,
	expiresAt: number,
}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function Rules.isSessionId(value: any): boolean
	return typeof(value) == "string"
		and #value >= Config.SessionIdMinLength
		and #value <= Config.SessionIdMaxLength
end

function Rules.isRecord(value: any): boolean
	if typeof(value) ~= "table" then return false end
	return value.version == Config.Version
		and Rules.isSessionId(value.sessionId)
		and typeof(value.jobId) == "string"
		and value.jobId ~= ""
		and typeof(value.placeId) == "number"
		and finite(value.placeId)
		and typeof(value.refreshedAt) == "number"
		and finite(value.refreshedAt)
		and typeof(value.expiresAt) == "number"
		and finite(value.expiresAt)
end

function Rules.isExpired(value: any, now: number): boolean
	return Rules.isRecord(value) and value.expiresAt <= now
end

function Rules.canClaim(value: any, requestedSessionId: string, now: number): (boolean, string?)
	if value == nil then return true, nil end
	if not Rules.isRecord(value) then return false, "InvalidRecord" end
	if value.expiresAt <= now then return true, nil end
	if value.sessionId == requestedSessionId then return true, nil end
	return false, "Busy"
end

function Rules.isOwner(value: any, sessionId: string, jobId: string): boolean
	return Rules.isRecord(value)
		and value.sessionId == sessionId
		and value.jobId == jobId
end

function Rules.makeRecord(
	sessionId: string,
	jobId: string,
	placeId: number,
	now: number,
	ttlSeconds: number
): SessionRecord
	assert(Rules.isSessionId(sessionId), "invalid session id")
	assert(jobId ~= "", "job id must not be empty")
	assert(finite(now), "time must be finite")
	assert(finite(ttlSeconds) and ttlSeconds > 0, "ttl must be positive")
	return {
		version = Config.Version,
		sessionId = sessionId,
		jobId = jobId,
		placeId = placeId,
		refreshedAt = now,
		expiresAt = now + ttlSeconds,
	}
end

function Rules.readRoutedSessionId(payload: any, userId: number): string?
	if typeof(payload) ~= "table" or typeof(payload.experienceSessionIds) ~= "table" then
		return nil
	end
	local value = payload.experienceSessionIds[tostring(userId)]
	return if Rules.isSessionId(value) then value else nil
end

return table.freeze(Rules)
