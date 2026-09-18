--!strict

local SkillRules = {}

export type AreaCandidate = {
	entityId: string,
	distance: number,
}

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

export type FriendlyTargetResolution = "Selected" | "Self"

function SkillRules.resolveFriendlyTarget(
	actorAlive: boolean,
	hasSelectedPlayer: boolean,
	selectedPlayerAlive: boolean,
	selectedPlayerInRange: boolean,
	selfCastWithoutFriendlyTarget: boolean
): FriendlyTargetResolution?
	if not actorAlive then return nil end
	if hasSelectedPlayer and selectedPlayerAlive and selectedPlayerInRange then return "Selected" end
	if selfCastWithoutFriendlyTarget then return "Self" end
	return nil
end

function SkillRules.isAcceptedTargetIdentityCurrent(
	acceptedKind: "Mob" | "Player",
	acceptedEntityId: string,
	acceptedModel: unknown,
	resolvedKind: "Mob" | "Player"?,
	resolvedEntityId: string?,
	resolvedModel: unknown
): boolean
	return resolvedKind == acceptedKind
		and resolvedEntityId == acceptedEntityId
		and resolvedModel ~= nil
		and resolvedModel == acceptedModel
end

function SkillRules.resolveHealing(currentHealth: number, maximumHealth: number, amount: number, targetAlive: boolean): number?
	if not targetAlive or currentHealth <= 0 or maximumHealth <= 0 or amount < 0 then return nil end
	return math.min(currentHealth + amount, maximumHealth)
end

function SkillRules.selectAreaTargets(
	candidates: { AreaCandidate },
	radius: number,
	maximumTargets: number
): { string }
	assert(radius >= 0, "radius must be nonnegative")
	assert(maximumTargets >= 1 and maximumTargets % 1 == 0, "maximumTargets must be a positive integer")
	local eligible: { AreaCandidate } = {}
	for _, candidate in candidates do
		if candidate.distance <= radius then
			table.insert(eligible, candidate)
		end
	end
	table.sort(eligible, function(left, right)
		if left.distance == right.distance then return left.entityId < right.entityId end
		return left.distance < right.distance
	end)
	local selected: { string } = {}
	for index = 1, math.min(#eligible, maximumTargets) do
		table.insert(selected, eligible[index].entityId)
	end
	return selected
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
