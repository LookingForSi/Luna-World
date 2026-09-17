--!strict

local RemoteRequestRules = {}

local MAX_IDENTIFIER_LENGTH = 128

local function validatedIdentifier(argumentCount: number, value: unknown): string?
	if argumentCount ~= 1 or typeof(value) ~= "string" then return nil end
	if #value > MAX_IDENTIFIER_LENGTH then return nil end
	return value
end

function RemoteRequestRules.validateTargetRequest(argumentCount: number, entityId: unknown): string?
	return validatedIdentifier(argumentCount, entityId)
end

function RemoteRequestRules.validateAttackRequest(argumentCount: number): boolean
	return argumentCount == 0
end

function RemoteRequestRules.validateAutoAttackRequest(argumentCount: number, enabled: unknown): boolean?
	if argumentCount ~= 1 or typeof(enabled) ~= "boolean" then return nil end
	return enabled
end

function RemoteRequestRules.validateSkillRequest(argumentCount: number, skillId: unknown): string?
	local identifier = validatedIdentifier(argumentCount, skillId)
	if identifier == "" then return nil end
	return identifier
end

return RemoteRequestRules
