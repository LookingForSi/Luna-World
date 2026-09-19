--!strict

local ProgressionConfig = require(script.Parent.Parent.config.ProgressionConfig)

local ProgressionRules = {}

export type ProgressionResult = {
	level: number,
	xp: number,
	levelsGained: number,
}

local function isFiniteNumber(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function ProgressionRules.requiredXP(level: number): number?
	assert(isFiniteNumber(level) and level % 1 == 0, "level must be a finite integer")
	assert(level >= 1 and level <= ProgressionConfig.LevelCap, "level is outside the supported range")
	if level >= ProgressionConfig.LevelCap then
		return nil
	end
	return ProgressionConfig.ExperienceRequiredByLevel[level]
end

function ProgressionRules.isValidState(level: number, xp: number): boolean
	if not isFiniteNumber(level) or level % 1 ~= 0 or level < 1 or level > ProgressionConfig.LevelCap then
		return false
	end
	if not isFiniteNumber(xp) or xp < 0 or xp % 1 ~= 0 then
		return false
	end
	local required = ProgressionRules.requiredXP(level)
	if required == nil then
		return xp == 0
	end
	return xp < required
end

function ProgressionRules.applyXP(level: number, xp: number, reward: number): ProgressionResult
	assert(ProgressionRules.isValidState(level, xp), "invalid progression state")
	assert(isFiniteNumber(reward) and reward >= 0 and reward % 1 == 0, "XP reward must be a finite nonnegative integer")

	if level >= ProgressionConfig.LevelCap or reward == 0 then
		return { level = level, xp = xp, levelsGained = 0 }
	end

	local nextLevel = level
	local nextXP = xp + reward
	local gained = 0

	while nextLevel < ProgressionConfig.LevelCap do
		local required = ProgressionConfig.ExperienceRequiredByLevel[nextLevel]
		assert(required ~= nil and required > 0, "missing XP requirement for progression level")
		if nextXP < required then
			break
		end
		nextXP -= required
		nextLevel += 1
		gained += 1
	end

	if nextLevel >= ProgressionConfig.LevelCap then
		nextXP = 0
	end

	return {
		level = nextLevel,
		xp = nextXP,
		levelsGained = gained,
	}
end

function ProgressionRules.isSkillUnlocked(requiredLevel: number, level: number): boolean
	if not isFiniteNumber(requiredLevel) or requiredLevel % 1 ~= 0 or requiredLevel < 1 or requiredLevel > ProgressionConfig.LevelCap then
		return false
	end
	if not isFiniteNumber(level) or level % 1 ~= 0 or level < 1 or level > ProgressionConfig.LevelCap then
		return false
	end
	return level >= requiredLevel
end

return table.freeze(ProgressionRules)
