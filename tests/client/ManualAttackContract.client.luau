--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local targetRequest = remotes:WaitForChild("TargetRequest") :: RemoteEvent
local attackRequest = remotes:WaitForChild("AttackRequest") :: RemoteEvent
local skillRequest = remotes:WaitForChild("SkillRequest") :: RemoteEvent
local skillResult = remotes:WaitForChild("SkillResult") :: RemoteEvent
local readinessFunction = ReplicatedStorage
	:WaitForChild("TestRemotes")
	:WaitForChild("MilestoneZeroAttackContractReady") :: RemoteFunction
local completionEvent = ReplicatedStorage
	:WaitForChild("TestRemotes")
	:WaitForChild("MilestoneZeroAttackContractComplete") :: RemoteEvent
local lifecycleStart = ReplicatedStorage.TestRemotes:WaitForChild("ManualAttackLifecycleStart") :: RemoteEvent
local lifecycleCommand = ReplicatedStorage.TestRemotes:WaitForChild("ManualAttackLifecycleCommand") :: RemoteFunction
local lifecycleComplete = ReplicatedStorage.TestRemotes:WaitForChild("ManualAttackLifecycleComplete") :: RemoteEvent
local skillRuntimeStart = ReplicatedStorage.TestRemotes:WaitForChild("SkillRuntimeStart") :: RemoteEvent
local skillRuntimeCommand = ReplicatedStorage.TestRemotes:WaitForChild("SkillRuntimeCommand") :: RemoteFunction
local skillRuntimeComplete = ReplicatedStorage.TestRemotes:WaitForChild("SkillRuntimeComplete") :: RemoteEvent

local skillResults: { any } = {}
local skillRuntimeStarted = false
skillRuntimeStart.OnClientEvent:Connect(function()
	skillRuntimeStarted = true
end)
skillResult.OnClientEvent:Connect(function(result: unknown)
	assert(typeof(result) == "table", "SkillResult must be a server result record")
	table.insert(skillResults, result)
end)

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

waitUntil("skill runtime fixture start", 5, function()
	return skillRuntimeStarted
end)
waitUntil("manual action slot before skill fixture", CombatConfig.BasicAttackInterval + 2, function()
	return player:GetAttribute(CombatConfig.BasicActionStateAttribute) == "Ready"
end)

local function prepareSkillTarget(): (string, Humanoid)
	local preparedEntityId = skillRuntimeCommand:InvokeServer("PrepareTarget")
	assert(typeof(preparedEntityId) == "string")
	targetRequest:FireServer(preparedEntityId)
	waitUntil("server-confirmed skill target", 3, function()
		return player:GetAttribute(CombatConfig.SelectedTargetAttribute) == preparedEntityId
	end)
	local preparedModel: Model? = nil
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("EntityId") == preparedEntityId then
			preparedModel = child
			break
		end
	end
	assert(preparedModel ~= nil)
	local preparedHumanoid = preparedModel:FindFirstChildOfClass("Humanoid")
	assert(preparedHumanoid ~= nil)
	return preparedEntityId, preparedHumanoid
end

local function waitForSkillResult(expectedCount: number, description: string): any
	waitUntil(description, 4, function()
		return #skillResults >= expectedCount
	end)
	return skillResults[expectedCount]
end

local powerStrike = SkillDefinitions.power_strike
local _, skillTargetHumanoid = prepareSkillTarget()
local initialSkillHealth = skillTargetHumanoid.Health
local initialSkillResource = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
assert(typeof(initialSkillResource) == "number")

-- Extra client-owned outcome fields invalidate the whole request and mutate nothing.
skillRequest:FireServer("power_strike", { damage = 999999, isCritical = true, timestamp = 0, targets = {} })
task.wait(powerStrike.windupSeconds + 0.15)
assert(#skillResults == 0)
assert(player:GetAttribute(CombatConfig.ResourceCurrentAttribute) == initialSkillResource)
assert(skillTargetHumanoid.Health == initialSkillHealth)

-- One accepted request owns one action id, one cost, and one terminal result.
skillRequest:FireServer("power_strike")
skillRequest:FireServer("power_strike")
waitUntil("accepted skill windup", 3, function()
	return player:GetAttribute(CombatConfig.BasicActionStateAttribute) == "Windup"
end)
local firstSkillResult = waitForSkillResult(1, "one direct skill result")
assert(typeof(firstSkillResult.actionId) == "string" and firstSkillResult.actionId ~= "")
assert(firstSkillResult.skillId == "power_strike" and firstSkillResult.applied == true)
assert(player:GetAttribute(CombatConfig.BasicActionStateAttribute) == "Ready", "state must reset before result delivery")
local resourceAfterAcceptedSkill = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
assert(typeof(resourceAfterAcceptedSkill) == "number")
assert(resourceAfterAcceptedSkill <= initialSkillResource)
assert(resourceAfterAcceptedSkill >= initialSkillResource - powerStrike.resourceCost)
assert(resourceAfterAcceptedSkill > initialSkillResource - (powerStrike.resourceCost * 2), "concurrent request spent resource twice")
assert(skillTargetHumanoid.Health < initialSkillHealth)
task.wait(0.15)
assert(#skillResults == 1, "concurrent request must not create another result")

-- The skill's own cooldown rejects another request without mutation.
local afterFirstResource = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
skillRequest:FireServer("power_strike")
task.wait(powerStrike.windupSeconds + 0.1)
assert(#skillResults == 1)
local resourceAfterCooldownRejection = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
assert(typeof(resourceAfterCooldownRejection) == "number" and typeof(afterFirstResource) == "number")
assert(resourceAfterCooldownRejection > afterFirstResource - (powerStrike.resourceCost * 0.5), "cooldown rejection spent resource")

task.wait(powerStrike.cooldownSeconds + 0.1)
prepareSkillTarget()
skillRequest:FireServer("power_strike")
waitUntil("resolve-failure windup", 3, function()
	return player:GetAttribute(CombatConfig.BasicActionStateAttribute) == "Windup"
end)
assert(skillRuntimeCommand:InvokeServer("MoveTargetOutOfRange") == true)
local failedResult = waitForSkillResult(2, "resolve-failure terminal result")
assert(failedResult.applied == false and failedResult.reason == "ResolveFailed")
assert(typeof(failedResult.actionId) == "string" and failedResult.actionId ~= firstSkillResult.actionId)
assert(player:GetAttribute(CombatConfig.BasicActionStateAttribute) == "Ready")

-- Death cancels exactly once; the respawned CharacterAdded state retains the cooldown.
task.wait(powerStrike.cooldownSeconds + 0.1)
prepareSkillTarget()
skillRequest:FireServer("power_strike")
waitUntil("pre-death skill windup", 3, function()
	return player:GetAttribute(CombatConfig.BasicActionStateAttribute) == "Windup"
end)
assert(skillRuntimeCommand:InvokeServer("KillActor") == true)
local canceledResult = waitForSkillResult(3, "death-canceled terminal result")
assert(canceledResult.applied == false and canceledResult.reason == "Canceled")
task.wait(powerStrike.windupSeconds + 0.1)
assert(#skillResults == 3, "canceled delayed resolve must not duplicate its result")

waitUntil("skill fixture respawn", 5, function()
	local character = player.Character
	local livingHumanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return livingHumanoid ~= nil and livingHumanoid.Health > 0
end)
waitUntil("full respawn resource snapshot", 3, function()
	return player:GetAttribute(CombatConfig.ResourceCurrentAttribute) == CombatConfig.ArchetypeStats.knight.maximumResource
end)
prepareSkillTarget()
local respawnResource = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
skillRequest:FireServer("power_strike")
task.wait(powerStrike.windupSeconds + 0.15)
assert(#skillResults == 3, "CharacterAdded must not erase the accepted skill cooldown")
assert(player:GetAttribute(CombatConfig.ResourceCurrentAttribute) == respawnResource)

skillRuntimeComplete:FireServer()
print("[PASS] authoritative SkillRequest runtime contract")
