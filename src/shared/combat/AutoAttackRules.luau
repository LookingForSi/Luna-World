--!strict

local AutoAttackRules = {}

export type RequestDecision = { accepted: boolean, enabled: boolean? }

function AutoAttackRules.isExactBooleanRequest(argumentCount: number, enabled: unknown): boolean
	return argumentCount == 1 and typeof(enabled) == "boolean"
end

function AutoAttackRules.validateRequest(argumentCount: number, enabled: unknown, actorAlive: boolean, hasLivingMobTarget: boolean): RequestDecision
	if not AutoAttackRules.isExactBooleanRequest(argumentCount, enabled) then return { accepted = false } end
	if enabled and (not actorAlive or not hasLivingMobTarget) then return { accepted = false } end
	return { accepted = true, enabled = enabled }
end

function AutoAttackRules.shouldStop(playerPresent: boolean, actorAlive: boolean, characterMatches: boolean, hasLivingMobTarget: boolean): boolean
	return not playerPresent or not actorAlive or not characterMatches or not hasLivingMobTarget
end

function AutoAttackRules.nextAttemptAt(now: number, readyAt: number, retryInterval: number): number
	if readyAt > now then return readyAt end
	return now + retryInterval
end

function AutoAttackRules.shouldAttempt(now: number, nextAttemptAt: number, actionState: string): boolean
	return now >= nextAttemptAt and actionState == "Ready"
end

return AutoAttackRules
