--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local targetRequest = remotes:WaitForChild("TargetRequest") :: RemoteEvent
local attackRequest = remotes:WaitForChild("AttackRequest") :: RemoteEvent
local readinessFunction = ReplicatedStorage
	:WaitForChild("TestRemotes")
	:WaitForChild("MilestoneZeroAttackContractReady") :: RemoteFunction
local completionEvent = ReplicatedStorage
	:WaitForChild("TestRemotes")
	:WaitForChild("MilestoneZeroAttackContractComplete") :: RemoteEvent

local function waitUntil(description: string, timeoutSeconds: number, predicate: () -> boolean): ()
	local deadline = os.clock() + timeoutSeconds
	while not predicate() and os.clock() < deadline do
		task.wait()
	end
	assert(predicate(), string.format("timed out waiting for %s", description))
end

local target: Model? = nil
local entityId: string? = nil
assert(readinessFunction:InvokeServer() == true, "server runtime characterization fixture is not ready")
waitUntil("a living milestone zero grey wolf", 12, function()
	for _, child in workspace:GetChildren() do
		local humanoid = child:FindFirstChildOfClass("Humanoid")
		local candidateEntityId = child:GetAttribute("EntityId")
		if child:IsA("Model")
			and child:GetAttribute("MobId") == "mob_grey_wolf"
			and typeof(candidateEntityId) == "string"
			and humanoid ~= nil
			and humanoid.Health > 0
		then
			target = child
			entityId = candidateEntityId
			return true
		end
	end
	return false
end)

assert(target ~= nil and entityId ~= nil)
local selectedTarget = target :: Model
local humanoid = selectedTarget:FindFirstChildOfClass("Humanoid")
assert(humanoid ~= nil, "milestone zero grey wolf must have a Humanoid")
local initialHealth = humanoid.Health
targetRequest:FireServer(entityId)
waitUntil("server-confirmed target selection", 3, function()
	return player:GetAttribute("SelectedTargetEntityId") == entityId
end)

attackRequest:FireServer(true)
waitUntil("server-owned active attack state", 3, function()
	return player:GetAttribute("IsBasicAttacking") == true
end)
waitUntil("first server-authoritative basic attack hit", 3, function()
	return humanoid.Health == initialHealth - CombatConfig.BasicAttackDamage
end)
local firstHitObservedAt = os.clock()
local readyAt = firstHitObservedAt + CombatConfig.BasicAttackInterval

task.wait(CombatConfig.BasicAttackInterval * 0.5)
attackRequest:FireServer(true)
assert(player:GetAttribute("IsBasicAttacking") == true, "repeated true must preserve the active attack state")

local earlyBoundary = readyAt - 0.1
while os.clock() < earlyBoundary do
	assert(
		humanoid.Health == initialHealth - CombatConfig.BasicAttackDamage,
		"repeated true must not create duplicate or early damage"
	)
	task.wait()
end

waitUntil("second hit on the original cadence", CombatConfig.BasicAttackInterval, function()
	return humanoid.Health ~= initialHealth - CombatConfig.BasicAttackDamage
end)
local secondHitObservedAt = os.clock()
assert(
	humanoid.Health == initialHealth - (2 * CombatConfig.BasicAttackDamage),
	"one cadence interval must apply exactly one additional hit"
)
assert(secondHitObservedAt >= readyAt - 0.1, "second hit occurred before the server cooldown elapsed")
assert(secondHitObservedAt <= readyAt + 0.35, "repeated true reset or delayed the existing attack cadence")

attackRequest:FireServer(false)
waitUntil("server-owned cancelled attack state", 3, function()
	return player:GetAttribute("IsBasicAttacking") == false
end)
task.wait(0.1)
assert(
	humanoid.Health == initialHealth - (2 * CombatConfig.BasicAttackDamage),
	"cancelling after the second hit must prevent duplicate damage"
)

completionEvent:FireServer()
print("[PASS] milestone zero AttackRequest runtime contract")
