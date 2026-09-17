--!strict

local ActionRules = {}

export type TimingDecision =
	{ kind: "Accept" }
	| { kind: "Buffer" }
	| { kind: "Reject", reason: "Cooldown" }

function ActionRules.evaluateTiming(
	now: number,
	readyAt: number,
	bufferWindowSeconds: number,
	hasBufferedRequest: boolean
): TimingDecision
	assert(bufferWindowSeconds >= 0, "bufferWindowSeconds must not be negative")

	-- This function evaluates a new incoming request. A stored request is consumed
	-- by the server lifecycle, not by accepting another input into the same slot.
	if hasBufferedRequest then
		return { kind = "Reject", reason = "Cooldown" }
	end

	if now >= readyAt then
		return { kind = "Accept" }
	end

	if now >= readyAt - bufferWindowSeconds then
		return { kind = "Buffer" }
	end

	return { kind = "Reject", reason = "Cooldown" }
end

function ActionRules.shouldClearBuffer(
	bufferedTargetId: string,
	currentTargetId: string?,
	actorAlive: boolean,
	forbiddenState: boolean
): boolean
	return not actorAlive or forbiddenState or currentTargetId ~= bufferedTargetId
end

function ActionRules.isWithinRange(
	actorPosition: Vector3,
	targetPosition: Vector3,
	actionRange: number,
	rangeTolerance: number
): boolean
	assert(actionRange >= 0, "actionRange must not be negative")
	assert(rangeTolerance >= 0, "rangeTolerance must not be negative")
	return (targetPosition - actorPosition).Magnitude <= actionRange + rangeTolerance
end

function ActionRules.isFacing(
	actorPosition: Vector3,
	actorForward: Vector3,
	targetPosition: Vector3,
	facingArcDegrees: number
): boolean
	assert(facingArcDegrees >= 0 and facingArcDegrees <= 360, "facingArcDegrees must be between 0 and 360")

	local toTarget = Vector3.new(targetPosition.X - actorPosition.X, 0, targetPosition.Z - actorPosition.Z)
	if toTarget.Magnitude == 0 then
		return true
	end

	local horizontalForward = Vector3.new(actorForward.X, 0, actorForward.Z)
	if horizontalForward.Magnitude == 0 then
		return false
	end

	local minimumDot = math.cos(math.rad(facingArcDegrees / 2))
	return horizontalForward.Unit:Dot(toTarget.Unit) >= minimumDot
end

function ActionRules.canStartAction(actionState: "Ready" | "Windup" | "Recovery"): boolean
	return actionState == "Ready"
end

return table.freeze(ActionRules)
