--!strict

local AutoAttackToggleRules = {}

export type State = {
	authoritative: boolean,
	desired: boolean,
	pending: boolean,
	generation: number,
}

function AutoAttackToggleRules.create(authoritative: boolean): State
	return { authoritative = authoritative, desired = authoritative, pending = false, generation = 0 }
end

function AutoAttackToggleRules.requestToggle(state: State): (boolean?, number?)
	if state.pending then return nil, nil end
	state.desired = not state.authoritative
	state.pending = true
	state.generation += 1
	return state.desired, state.generation
end

function AutoAttackToggleRules.reconcile(state: State, authoritative: boolean): ()
	state.authoritative = authoritative
	state.desired = authoritative
	state.pending = false
end

function AutoAttackToggleRules.expire(state: State, generation: number): ()
	if state.pending and state.generation == generation then
		state.desired = state.authoritative
		state.pending = false
	end
end

return AutoAttackToggleRules
