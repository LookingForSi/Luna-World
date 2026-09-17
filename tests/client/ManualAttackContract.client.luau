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
local lifecycleStart = ReplicatedStorage.TestRemotes:WaitForChild("ManualAttackLifecycleStart") :: RemoteEvent
local lifecycleCommand = ReplicatedStorage.TestRemotes:WaitForChild("ManualAttackLifecycleCommand") :: RemoteFunction
local lifecycleComplete = ReplicatedStorage.TestRemotes:WaitForChild("ManualAttackLifecycleComplete") :: RemoteEvent

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
waitUntil("default knight combat snapshot", 3, function()
	return player:GetAttribute(CombatConfig.ArchetypeAttribute) == "knight"
		and player:GetAttribute(CombatConfig.ResourceTypeAttribute) == "Stamina"
		and player:GetAttribute(CombatConfig.ResourceCurrentAttribute) == CombatConfig.ArchetypeStats.knight.maximumResource
		and player:GetAttribute(CombatConfig.ResourceMaximumAttribute) == CombatConfig.ArchetypeStats.knight.maximumResource
end)
local baseAttackDamage = CombatConfig.ArchetypeStats.knight.physicalAttack
targetRequest:FireServer(entityId)
waitUntil("server-confirmed target selection", 3, function()
	return player:GetAttribute("SelectedTargetEntityId") == entityId
end)

-- Legacy boolean payloads must be rejected without damage.
attackRequest:FireServer(true)
attackRequest:FireServer(false)
attackRequest:FireServer("unexpected", 1)
task.wait(CombatConfig.BasicAttackWindupSeconds + 0.05)
assert(humanoid.Health == initialHealth, "legacy AttackRequest payloads must be rejected")

attackRequest:FireServer()
waitUntil("first server-authoritative basic attack hit", 3, function()
	return humanoid.Health < initialHealth
end)
local healthAfterFirstHit = humanoid.Health
local firstDamage = initialHealth - healthAfterFirstHit
assert(
	firstDamage == baseAttackDamage
		or firstDamage == baseAttackDamage * CombatConfig.CriticalDamageMultiplier,
	"basic attack damage must be a server-resolved normal or critical result"
)
local readyAt = player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute)
assert(typeof(readyAt) == "number", "server ready deadline must replicate")

task.wait(CombatConfig.BasicAttackInterval * 0.5)
attackRequest:FireServer()

local earlyBoundary = readyAt - 0.1
while workspace:GetServerTimeNow() < earlyBoundary do
	assert(
		humanoid.Health == healthAfterFirstHit,
		"repeated true must not create duplicate or early damage"
	)
	task.wait()
end

-- A request in the short pre-readiness window occupies the single buffer slot.
while workspace:GetServerTimeNow() < readyAt - (CombatConfig.InputBufferSeconds * 0.5) do
	task.wait()
end
attackRequest:FireServer()
attackRequest:FireServer()

waitUntil("one buffered hit on the original cadence", CombatConfig.BasicAttackInterval, function()
	return humanoid.Health < healthAfterFirstHit
end)
local secondHitObservedAt = workspace:GetServerTimeNow()
local healthAfterSecondHit = humanoid.Health
local secondDamage = healthAfterFirstHit - healthAfterSecondHit
assert(
	secondDamage == baseAttackDamage
		or secondDamage == baseAttackDamage * CombatConfig.CriticalDamageMultiplier,
	"one cadence interval must apply exactly one additional hit"
)
assert(secondHitObservedAt >= readyAt - 0.1, "second hit occurred before the server cooldown elapsed")
assert(secondHitObservedAt <= readyAt + 0.35, "buffered request did not execute at readiness")

task.wait(0.1)
assert(
	humanoid.Health == healthAfterSecondHit,
	"repeated requests must not apply duplicate damage"
)

completionEvent:FireServer()

lifecycleStart.OnClientEvent:Wait()

local function prepareAndSelectTarget(): string
	local preparedEntityId = lifecycleCommand:InvokeServer("PrepareTarget")
	assert(typeof(preparedEntityId) == "string")
	targetRequest:FireServer(preparedEntityId)
	waitUntil("server-confirmed lifecycle target", 3, function()
		return player:GetAttribute(CombatConfig.SelectedTargetAttribute) == preparedEntityId
	end)
	return preparedEntityId
end

local function waitForWindup(): ()
	waitUntil("replicated accepted attack windup", 3, function()
		return player:GetAttribute(CombatConfig.BasicActionStateAttribute) == "Windup"
	end)
end

local function assertCleanCombatState(description: string, requireCooldownReset: boolean): ()
	waitUntil(description, CombatConfig.BasicAttackInterval + 3, function()
		local baseClean = player:GetAttribute(CombatConfig.BasicActionStateAttribute) == "Ready"
			and player:GetAttribute(CombatConfig.SelectedTargetAttribute) == nil
			and player:GetAttribute(CombatConfig.BasicAttackBufferedAttribute) == false
		return baseClean
			and (not requireCooldownReset or player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute) == 0)
	end)
end

-- A target dying during wind-up invalidates resolve; no accepted action may remain stale.
prepareAndSelectTarget()
attackRequest:FireServer()
waitForWindup()
assert(lifecycleCommand:InvokeServer("KillTarget") == true)
assertCleanCombatState("target-death cleanup", false)

-- Actor death clears target, pending action, cooldown feedback, and the buffer slot.
prepareAndSelectTarget()
attackRequest:FireServer()
waitForWindup()
assert(lifecycleCommand:InvokeServer("KillActor") == true)
assertCleanCombatState("actor-death cleanup", true)

waitUntil("replacement character after actor death", 12, function()
	local character = player.Character
	local livingHumanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return livingHumanoid ~= nil and livingHumanoid.Health > 0
end)

-- Explicit character replacement during wind-up invalidates the old generation.
prepareAndSelectTarget()
local replacedCharacter = player.Character
attackRequest:FireServer()
waitForWindup()
local oldGenerationReadyAt = player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute)
assert(typeof(oldGenerationReadyAt) == "number")
assert(lifecycleCommand:InvokeServer("ReplaceCharacter") == true)
waitUntil("explicitly replaced character", 12, function()
	return player.Character ~= nil and player.Character ~= replacedCharacter
end)
assertCleanCombatState("character-replacement cleanup", true)

-- A fresh action after replacement must not be changed by the old generation's delayed recovery callback.
prepareAndSelectTarget()
attackRequest:FireServer()
waitForWindup()
local freshReadyAt = player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute)
assert(typeof(freshReadyAt) == "number")
if freshReadyAt > oldGenerationReadyAt + 0.05 then
	while workspace:GetServerTimeNow() < oldGenerationReadyAt + 0.03 do
		task.wait()
	end
	assert(
		player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute) == freshReadyAt,
		"old generation timer must not overwrite fresh action deadline"
	)
	assert(
		player:GetAttribute(CombatConfig.BasicActionStateAttribute) ~= "Ready",
		"old generation timer must not make a fresh action ready"
	)
end

lifecycleComplete:FireServer()
print("[PASS] milestone one manual AttackRequest runtime contract")
