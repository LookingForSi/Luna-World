--!strict

local SkillRules = {}

export type RequestDecision =
	{ accepted: true }
	| { accepted: false, reason: "InvalidRequest" | "UnknownSkill" | "WrongArchetype" | "BasicAttack" }

function SkillRules.validateRequest(
	argumentCount: number,
	skillId: unknown,
	definitionExists: boolean,
	definitionArchetypeId: string?,
	actorArchetypeId: string,
	isBasicAttack: boolean
): RequestDecision
	if argumentCount ~= 1 or typeof(skillId) ~= "string" then
		return { accepted = false, reason = "InvalidRequest" }
	end
	if not definitionExists then
		return { accepted = false, reason = "UnknownSkill" }
	end
	if definitionArchetypeId ~= actorArchetypeId then
		return { accepted = false, reason = "WrongArchetype" }
	end
	if isBasicAttack then
		return { accepted = false, reason = "BasicAttack" }
	end
	return { accepted = true }
end

function SkillRules.canAccept(
	actionState: "Ready" | "Windup" | "Recovery",
	cooldownReady: boolean,
	hasResource: boolean,
	targetValid: boolean
): boolean
	return actionState == "Ready" and cooldownReady and hasResource and targetValid
end

function SkillRules.isEnemyTargetValid(
	selectedTargetId: string?,
	resolvedTargetId: string?,
	actorAlive: boolean,
	targetAlive: boolean,
	inRange: boolean,
	isFacing: boolean
): boolean
	return selectedTargetId ~= nil
		and selectedTargetId == resolvedTargetId
		and actorAlive
		and targetAlive
		and inRange
		and isFacing
end

function SkillRules.shouldSelfCastFriendly(
	hasValidFriendlyTarget: boolean,
	selfCastWithoutFriendlyTarget: boolean
): boolean
	return not hasValidFriendlyTarget and selfCastWithoutFriendlyTarget
end

function SkillRules.isTargetContextAllowed(
	targetType: "Enemy" | "Self" | "Friendly" | "EnemyArea",
	targetKind: "Mob" | "Player",
	isActor: boolean
): boolean
	if targetType == "Enemy" or targetType == "EnemyArea" then
		return targetKind == "Mob" and not isActor
	end
	if targetType == "Self" then
		return targetKind == "Player" and isActor
	end
	return targetKind == "Player"
end

return table.freeze(SkillRules)
