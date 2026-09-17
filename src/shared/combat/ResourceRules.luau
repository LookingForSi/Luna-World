--!strict

local CombatTypes = require(script.Parent.Parent.types.CombatTypes)

local ResourceRules = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function validateResource(resource: CombatTypes.CombatResource): ()
	assert(isFinite(resource.current), "current resource must be finite")
	assert(isFinite(resource.maximum), "maximum resource must be finite")
	assert(resource.maximum >= 0, "maximum resource must not be negative")
	assert(resource.current >= 0 and resource.current <= resource.maximum, "current resource must be within its bounds")
end

function ResourceRules.create(resourceType: CombatTypes.ResourceType, maximum: number): CombatTypes.CombatResource
	assert(isFinite(maximum) and maximum >= 0, "maximum resource must be finite and nonnegative")
	return { resourceType = resourceType, current = maximum, maximum = maximum }
end

function ResourceRules.canSpend(
	resource: CombatTypes.CombatResource,
	requiredType: CombatTypes.ResourceType,
	cost: number
): boolean
	validateResource(resource)
	assert(isFinite(cost) and cost >= 0, "resource cost must be finite and nonnegative")
	return resource.resourceType == requiredType and resource.current >= cost
end

function ResourceRules.spend(
	resource: CombatTypes.CombatResource,
	requiredType: CombatTypes.ResourceType,
	cost: number
): CombatTypes.CombatResource?
	if not ResourceRules.canSpend(resource, requiredType, cost) then
		return nil
	end
	return {
		resourceType = resource.resourceType,
		current = resource.current - cost,
		maximum = resource.maximum,
	}
end

function ResourceRules.restore(resource: CombatTypes.CombatResource, amount: number): CombatTypes.CombatResource
	validateResource(resource)
	assert(isFinite(amount) and amount >= 0, "restore amount must be finite and nonnegative")
	return {
		resourceType = resource.resourceType,
		current = math.min(resource.maximum, resource.current + amount),
		maximum = resource.maximum,
	}
end

function ResourceRules.regenerate(
	resource: CombatTypes.CombatResource,
	perSecond: number,
	elapsedSeconds: number
): CombatTypes.CombatResource
	assert(isFinite(perSecond) and perSecond >= 0, "regeneration must be finite and nonnegative")
	assert(isFinite(elapsedSeconds) and elapsedSeconds >= 0, "elapsedSeconds must be finite and nonnegative")
	return ResourceRules.restore(resource, perSecond * elapsedSeconds)
end

function ResourceRules.stepRegeneration(
	resource: CombatTypes.CombatResource,
	perSecond: number,
	accumulatedSeconds: number,
	deltaSeconds: number,
	intervalSeconds: number,
	isActive: boolean
): (CombatTypes.CombatResource, number)
	validateResource(resource)
	assert(isFinite(accumulatedSeconds) and accumulatedSeconds >= 0, "accumulatedSeconds must be finite and nonnegative")
	assert(isFinite(deltaSeconds) and deltaSeconds >= 0, "deltaSeconds must be finite and nonnegative")
	assert(isFinite(intervalSeconds) and intervalSeconds > 0, "intervalSeconds must be finite and positive")
	if not isActive then
		return resource, 0
	end

	local totalSeconds = accumulatedSeconds + deltaSeconds
	assert(isFinite(totalSeconds), "accumulated regeneration time must remain finite")
	local completedIntervals = math.floor(totalSeconds / intervalSeconds)
	if completedIntervals == 0 then
		return resource, totalSeconds
	end
	local elapsedToApply = completedIntervals * intervalSeconds
	return ResourceRules.regenerate(resource, perSecond, elapsedToApply), totalSeconds - elapsedToApply
end

return table.freeze(ResourceRules)
