--!strict

local RespawnRules = {}

export type AnchorCandidate = {
	id: string,
	position: Vector3,
	settlementId: string,
}

-- Returns a stable identifier rather than an Instance so the rule remains testable
-- and the server service retains ownership of world objects.
function RespawnRules.nearestAnchorId(origin: Vector3, anchors: { AnchorCandidate }): string?
	local nearestId: string? = nil
	local nearestDistance = math.huge
	for _, anchor in anchors do
		local distance = (anchor.position - origin).Magnitude
		if distance < nearestDistance or (distance == nearestDistance and (nearestId == nil or anchor.id < nearestId)) then
			nearestDistance = distance
			nearestId = anchor.id
		end
	end
	return nearestId
end

function RespawnRules.beginDeath(alreadyPending: boolean, generation: number): (boolean, number)
	if alreadyPending then return false, generation end
	return true, generation + 1
end

function RespawnRules.isCurrentGeneration(expected: number, current: number): boolean
	return expected == current
end

function RespawnRules.spawnCFrame(anchor: CFrame, humanoidHipHeight: number, rootHeight: number): CFrame
	assert(humanoidHipHeight >= 0 and rootHeight > 0, "character dimensions must be valid")
	return anchor + Vector3.new(0, humanoidHipHeight + rootHeight / 2, 0)
end

return table.freeze(RespawnRules)
