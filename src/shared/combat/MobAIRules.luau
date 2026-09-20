--!strict

local CombatTypes = require(script.Parent.Parent.types.CombatTypes)

export type State = "Idle" | "Aggro" | "Chase" | "Attack" | "Return" | "Dead"
export type Context = {
	alive: boolean,
	hasTarget: boolean,
	detectedTarget: boolean,
	hostileAttacker: boolean,
	beyondLeash: boolean,
	inAttackRange: boolean,
	atHome: boolean,
}
export type Candidate = { id: string, distance: number, eligible: boolean }

local MobAIRules = {}

function MobAIRules.nearestEligible(candidates: { Candidate }, radius: number): string?
	local selectedId: string? = nil
	local selectedDistance = math.huge
	for _, candidate in candidates do
		if candidate.eligible and candidate.distance <= radius and candidate.distance < selectedDistance then
			selectedId = candidate.id
			selectedDistance = candidate.distance
		end
	end
	return selectedId
end

function MobAIRules.isCurrentGeneration(capturedGeneration: number, currentGeneration: number): boolean
	return capturedGeneration == currentGeneration
end

function MobAIRules.canBeginDecision(now: number, nextDecisionAt: number, decisionInFlight: boolean): boolean
	return not decisionInFlight and now >= nextDecisionAt
end

function MobAIRules.shouldInvalidateAction(previousState: State, nextState: State): boolean
	return previousState ~= nextState and (nextState == "Return" or nextState == "Dead")
end

function MobAIRules.shouldRestoreHealth(previousState: State, nextState: State, configured: boolean): boolean
	return configured and previousState == "Return" and nextState == "Idle"
end

function MobAIRules.canRequestSocialAssist(state: State, socialGroupId: string?): boolean
	return state ~= "Return" and state ~= "Dead" and socialGroupId ~= nil and socialGroupId ~= ""
end

function MobAIRules.nextState(state: State, context: Context, aggressionMode: CombatTypes.AggressionMode): State
	if not context.alive then return "Dead" end
	if state == "Dead" then return "Dead" end
	-- Fresh hostile damage always re-engages a living mob, even if it had already
	-- started returning home. This prevents "invulnerable leash walks" while the
	-- player is visibly still fighting it.
	if context.hostileAttacker then return "Aggro" end
	if state == "Return" then return if context.atHome then "Idle" else "Return" end
	if context.beyondLeash then return "Return" end
	if state == "Idle" then
		if aggressionMode == "Aggressive" and context.detectedTarget then return "Aggro" end
		return "Idle"
	end
	if not context.hasTarget then return "Return" end
	if state == "Aggro" then return "Chase" end
	return if context.inAttackRange then "Attack" else "Chase"
end

return table.freeze(MobAIRules)
