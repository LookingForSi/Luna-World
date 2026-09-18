--!strict

local SkillActionLifecycle = {}

export type PendingAction = {
	actionId: string,
	skillId: string,
	targetEntityId: string,
	completed: boolean,
}

export type Slot = {
	pending: PendingAction?,
}

export type Result = {
	actionId: string,
	skillId: string,
	targetEntityId: string,
	applied: boolean,
	reason: string?,
}

function SkillActionLifecycle.createSlot(): Slot
	return { pending = nil }
end

function SkillActionLifecycle.shouldPreserveCooldowns(discardRuntimeState: boolean?): boolean
	return not discardRuntimeState
end

function SkillActionLifecycle.begin(
	slot: Slot,
	requestAccepted: boolean,
	actionId: string,
	skillId: string,
	targetEntityId: string
): PendingAction?
	if not requestAccepted or slot.pending ~= nil then return nil end
	assert(actionId ~= "", "actionId must not be empty")
	local pending = {
		actionId = actionId,
		skillId = skillId,
		targetEntityId = targetEntityId,
		completed = false,
	}
	slot.pending = pending
	return pending
end

function SkillActionLifecycle.finish(
	slot: Slot,
	pending: PendingAction,
	applied: boolean,
	reason: string?
): Result?
	if slot.pending ~= pending or pending.completed then return nil end
	pending.completed = true
	slot.pending = nil
	return {
		actionId = pending.actionId,
		skillId = pending.skillId,
		targetEntityId = pending.targetEntityId,
		applied = applied,
		reason = reason,
	}
end

return table.freeze(SkillActionLifecycle)
