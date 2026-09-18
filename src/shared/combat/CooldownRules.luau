--!strict

local CooldownRules = {}

export type CooldownDeadlines = { [string]: number }

function CooldownRules.isReady(cooldowns: CooldownDeadlines, cooldownGroup: string, now: number): boolean
	return now >= (cooldowns[cooldownGroup] or 0)
end

function CooldownRules.start(
	cooldowns: CooldownDeadlines,
	cooldownGroup: string,
	now: number,
	durationSeconds: number
): CooldownDeadlines
	assert(cooldownGroup ~= "", "cooldownGroup must not be empty")
	assert(durationSeconds >= 0, "durationSeconds must not be negative")

	local updated: CooldownDeadlines = table.clone(cooldowns)
	updated[cooldownGroup] = now + durationSeconds
	return updated
end

return table.freeze(CooldownRules)
