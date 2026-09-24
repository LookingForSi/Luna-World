--!strict

local KillCreditRules = {}

export type Candidate = {
	value: any,
	ready: boolean,
	alive: boolean,
	position: Vector3?,
}

function KillCreditRules.resolveEligible(candidates: { Candidate }, deathPosition: Vector3, radius: number): { any }
	local result = {}
	for _, candidate in candidates do
		if candidate.ready and candidate.alive and candidate.position ~= nil
			and (candidate.position - deathPosition).Magnitude <= radius then table.insert(result, candidate.value) end
	end
	return result
end

return table.freeze(KillCreditRules)
