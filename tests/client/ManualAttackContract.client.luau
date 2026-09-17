--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
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

local function cooldownAttribute(skillId: string): string
	return CombatConfig.SkillCooldownAttributePrefix .. skillId
end

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
local acceptedCooldownDeadline = player:GetAttribute(cooldownAttribute("power_strike"))
assert(typeof(acceptedCooldownDeadline) == "number" and acceptedCooldownDeadline > workspace:GetServerTimeNow(), "server must replicate the accepted skill cooldown deadline")
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
local preDeathCooldownDeadline = player:GetAttribute(cooldownAttribute("power_strike"))
assert(typeof(preDeathCooldownDeadline) == "number" and preDeathCooldownDeadline > workspace:GetServerTimeNow())
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
assert(player:GetAttribute(cooldownAttribute("power_strike")) == preDeathCooldownDeadline, "character replacement must preserve the authoritative cooldown deadline")
prepareSkillTarget()
local respawnResource = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
skillRequest:FireServer("power_strike")
task.wait(powerStrike.windupSeconds + 0.15)
assert(#skillResults == 3, "CharacterAdded must not erase the accepted skill cooldown")
assert(player:GetAttribute(CombatConfig.ResourceCurrentAttribute) == respawnResource)

-- Knight control and toggle effects remain server-owned and use the same skill executor.
local shieldBash = SkillDefinitions.shield_bash
local shieldBashEffect = shieldBash.effect
assert(shieldBashEffect.kind == "ShieldBash")
local shieldTargetId, shieldTargetHumanoid = prepareSkillTarget()
local shieldTarget = shieldTargetHumanoid.Parent
assert(shieldTarget ~= nil and shieldTarget:IsA("Model"))
local healthBeforeShieldBash = shieldTargetHumanoid.Health
skillRequest:FireServer("shield_bash")
local shieldResult = waitForSkillResult(4, "shield bash terminal result")
assert(shieldResult.applied == true and shieldResult.targetEntityId == shieldTargetId)
assert(shieldTargetHumanoid.Health < healthBeforeShieldBash, "shield bash must apply one physical hit")
assert(shieldTarget:GetAttribute(CombatConfig.MobStunnedAttribute) == true, "ordinary mob must be stunned")
assert(skillRuntimeCommand:InvokeServer("KillTarget") == true)
waitUntil("stun cleanup on target death", 2, function()
	return shieldTarget:GetAttribute(CombatConfig.MobStunnedAttribute) == nil
		and shieldTarget:GetAttribute(CombatConfig.MobStunnedUntilAttribute) == nil
end)

local defensiveStance = SkillDefinitions.defensive_stance
local defensiveStanceEffect = defensiveStance.effect
assert(defensiveStanceEffect.kind == "DefenseStance")
local function currentLivingHumanoid(): Humanoid
	local character = player.Character
	local candidate = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	assert(candidate ~= nil and candidate.Health > 0)
	return candidate
end

local stanceHumanoid = currentLivingHumanoid()
local baseWalkSpeed = CombatConfig.ArchetypeStats.knight.movementSpeed
local resourceBeforeStance = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
skillRequest:FireServer("defensive_stance")
skillRequest:FireServer("defensive_stance")
local enabledStanceResult = waitForSkillResult(5, "enabled defensive stance result")
assert(enabledStanceResult.applied == true)
task.wait(0.15)
assert(#skillResults == 5, "duplicate stance request must not produce a second accepted result")
assert(player:GetAttribute(CombatConfig.ResourceCurrentAttribute) == resourceBeforeStance)
assert(player.Character ~= nil and player.Character:GetAttribute(CombatConfig.DefenseStanceActiveAttribute) == true)
assert(stanceHumanoid.WalkSpeed == baseWalkSpeed * defensiveStanceEffect.movementSpeedMultiplier)

task.wait(defensiveStance.cooldownSeconds + 0.1)
skillRequest:FireServer("defensive_stance")
local disabledStanceResult = waitForSkillResult(6, "disabled defensive stance result")
assert(disabledStanceResult.applied == true)
assert(player.Character ~= nil and player.Character:GetAttribute(CombatConfig.DefenseStanceActiveAttribute) == nil)
assert(stanceHumanoid.WalkSpeed == baseWalkSpeed)

task.wait(defensiveStance.cooldownSeconds + 0.1)
skillRequest:FireServer("defensive_stance")
assert(waitForSkillResult(7, "re-enabled defensive stance result").applied == true)
assert(skillRuntimeCommand:InvokeServer("KillActor") == true)
waitUntil("respawn after defensive stance death", 5, function()
	local character = player.Character
	local livingHumanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return livingHumanoid ~= nil and livingHumanoid.Health > 0
		and character:GetAttribute(CombatConfig.DefenseStanceActiveAttribute) == nil
		and livingHumanoid.WalkSpeed == baseWalkSpeed
end)

-- Ranger effects execute through the same authoritative action pipeline.
local knightCharacter = player.Character
assert(skillRuntimeCommand:InvokeServer("BecomeRanger") == true)
waitUntil("ranger character and combat snapshot", 8, function()
	return player.Character ~= nil
		and player.Character ~= knightCharacter
		and player:GetAttribute(CombatConfig.ArchetypeAttribute) == "ranger"
		and player:GetAttribute(CombatConfig.ResourceTypeAttribute) == "Focus"
		and player:GetAttribute(CombatConfig.ResourceCurrentAttribute) == CombatConfig.ArchetypeStats.ranger.maximumResource
end)

local powerShot = SkillDefinitions.power_shot
local powerShotEffect = powerShot.effect
assert(powerShotEffect.kind == "DirectDamage")
local _, powerShotHumanoid = prepareSkillTarget()
local healthBeforePowerShot = powerShotHumanoid.Health
skillRequest:FireServer("power_shot")
task.wait(powerShot.windupSeconds * 0.5)
assert(powerShotHumanoid.Health == healthBeforePowerShot, "power shot must not resolve before its windup")
local powerShotResult = waitForSkillResult(8, "power shot terminal result")
assert(powerShotResult.applied == true and powerShotResult.skillId == "power_shot")
local healthAfterPowerShot = powerShotHumanoid.Health
local powerShotDamage = healthBeforePowerShot - healthAfterPowerShot
local rangerPhysicalAttack = CombatConfig.ArchetypeStats.ranger.physicalAttack
assert(
	math.abs(powerShotDamage - rangerPhysicalAttack * powerShotEffect.magnitude) < 0.001
		or math.abs(powerShotDamage - rangerPhysicalAttack * powerShotEffect.magnitude * CombatConfig.CriticalDamageMultiplier) < 0.001,
	"power shot must produce one server-calculated physical result"
)
task.wait(0.15)
assert(#skillResults == 8 and powerShotHumanoid.Health == healthAfterPowerShot, "power shot must resolve exactly once")

local rapidShot = SkillDefinitions.rapid_shot
local rapidShotEffect = rapidShot.effect
assert(rapidShotEffect.kind == "AttackSpeedBuff")
skillRequest:FireServer("rapid_shot")
local rapidShotResult = waitForSkillResult(9, "rapid shot terminal result")
assert(rapidShotResult.applied == true and rapidShotResult.amount == nil)
assert(player.Character ~= nil and player.Character:GetAttribute(CombatConfig.RapidShotActiveAttribute) == true)

local rapidTargetId = prepareSkillTarget()
local rapidAcceptedAt = workspace:GetServerTimeNow()
attackRequest:FireServer()
waitUntil("rapid shot basic attack deadline", 3, function()
	local deadline = player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute)
	return typeof(deadline) == "number" and deadline > rapidAcceptedAt
end)
local rapidReadyAt = player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute)
assert(typeof(rapidReadyAt) == "number")
local expectedRapidInterval = CombatConfig.RangerBasicAttackInterval / math.min(
	CombatConfig.ArchetypeStats.ranger.attackSpeedMultiplier * (1 + rapidShotEffect.magnitude),
	CombatConfig.MaxAttackSpeedMultiplier
)
assert(math.abs((rapidReadyAt - rapidAcceptedAt) - expectedRapidInterval) < 0.15, "rapid shot must accelerate basic cadence")
waitUntil("rapid basic attack recovery", CombatConfig.RangerBasicAttackInterval + 1, function()
	return player:GetAttribute(CombatConfig.BasicActionStateAttribute) == "Ready"
end)
waitUntil("rapid shot expiry", rapidShotEffect.durationSeconds + 1, function()
	return player.Character ~= nil and player.Character:GetAttribute(CombatConfig.RapidShotActiveAttribute) == nil
end)
targetRequest:FireServer(rapidTargetId)
local normalAcceptedAt = workspace:GetServerTimeNow()
attackRequest:FireServer()
waitUntil("restored ranger basic attack deadline", 3, function()
	local deadline = player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute)
	return typeof(deadline) == "number" and deadline > normalAcceptedAt
end)
local normalReadyAt = player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute)
assert(typeof(normalReadyAt) == "number")
assert(
	math.abs((normalReadyAt - normalAcceptedAt) - CombatConfig.RangerBasicAttackInterval) < 0.15,
	"rapid shot expiry must restore the recalculated base cadence"
)
waitUntil("normal ranger basic attack recovery", CombatConfig.RangerBasicAttackInterval + 1, function()
	return player:GetAttribute(CombatConfig.BasicActionStateAttribute) == "Ready"
end)

local snare = SkillDefinitions.snare
local snareEffect = snare.effect
assert(snareEffect.kind == "MovementSlow")
local _, snareHumanoid = prepareSkillTarget()
local snareModel = snareHumanoid.Parent
assert(snareModel ~= nil and snareModel:IsA("Model"))
local healthBeforeSnare = snareHumanoid.Health
skillRequest:FireServer("snare")
assert(waitForSkillResult(10, "first snare terminal result").applied == true)
assert(snareHumanoid.Health == healthBeforeSnare, "snare must not deal direct damage")
assert(snareHumanoid.WalkSpeed == MobDefinitions.grey_wolf.chaseSpeed * (1 - snareEffect.magnitude))
assert(skillRuntimeCommand:InvokeServer("KillTarget") == true)
waitUntil("snare cleanup after target death", 3, function()
	return snareModel:GetAttribute(CombatConfig.MobMovementSlowAttribute) == nil
end)

task.wait(snare.cooldownSeconds + 0.1)
local _, removedTargetHumanoid = prepareSkillTarget()
local removedTarget = removedTargetHumanoid.Parent
assert(removedTarget ~= nil and removedTarget:IsA("Model"))
skillRequest:FireServer("snare")
assert(waitForSkillResult(11, "removal cleanup snare result").applied == true)
assert(skillRuntimeCommand:InvokeServer("RemoveTarget") == true)
waitUntil("snared target removal", 3, function() return removedTarget.Parent == nil end)

-- Mystic damage, server-selected area damage, and self-healing use the same executor.
local rangerCharacter = player.Character
assert(skillRuntimeCommand:InvokeServer("BecomeMystic") == true)
waitUntil("mystic character and combat snapshot", 8, function()
	return player.Character ~= nil
		and player.Character ~= rangerCharacter
		and player:GetAttribute(CombatConfig.ArchetypeAttribute) == "mystic"
		and player:GetAttribute(CombatConfig.ResourceTypeAttribute) == "Mana"
		and player:GetAttribute(CombatConfig.ResourceCurrentAttribute) == CombatConfig.ArchetypeStats.mystic.maximumResource
end)

local arcaneBolt = SkillDefinitions.arcane_bolt
local arcaneEffect = arcaneBolt.effect
assert(arcaneEffect.kind == "DirectDamage")
local _, arcaneHumanoid = prepareSkillTarget()
local healthBeforeArcane = arcaneHumanoid.Health
skillRequest:FireServer("arcane_bolt")
local arcaneResult = waitForSkillResult(12, "arcane bolt terminal result")
assert(arcaneResult.applied == true and arcaneResult.skillId == "arcane_bolt")
assert(arcaneHumanoid.Health < healthBeforeArcane, "arcane bolt must apply one magical result")
local healthAfterArcane = arcaneHumanoid.Health
task.wait(0.15)
assert(#skillResults == 12 and arcaneHumanoid.Health == healthAfterArcane, "arcane bolt must resolve exactly once")

local flameBurst = SkillDefinitions.flame_burst
local flameEffect = flameBurst.effect
assert(flameEffect.kind == "AreaDamage")
local flameTargetId, flameHumanoid = prepareSkillTarget()
local healthBeforeFlame = flameHumanoid.Health
local selectedBeforeMalformedPlayer = player:GetAttribute(CombatConfig.SelectedTargetAttribute)
targetRequest:FireServer("player:" .. string.rep("9", 512))
targetRequest:FireServer("player:not-a-user-id")
task.wait(0.1)
assert(player:GetAttribute(CombatConfig.SelectedTargetAttribute) == selectedBeforeMalformedPlayer, "malformed player targets must not throw or mutate selection")
-- A target list is an extra argument and invalidates the request instead of influencing the server area query.
skillRequest:FireServer("flame_burst", { flameTargetId })
task.wait(flameBurst.windupSeconds + 0.1)
assert(#skillResults == 12 and flameHumanoid.Health == healthBeforeFlame)
skillRequest:FireServer("flame_burst")
local flameResult = waitForSkillResult(13, "flame burst terminal result")
assert(flameResult.applied == true and flameResult.skillId == "flame_burst")
assert(flameHumanoid.Health < healthBeforeFlame, "server-selected flame burst area must include its living center")

local heal = SkillDefinitions.heal
local healEffect = heal.effect
assert(healEffect.kind == "DirectHealing" and not heal.canCrit)
local damagedHealth = skillRuntimeCommand:InvokeServer("DamageActor")
assert(typeof(damagedHealth) == "number")
-- The selected hostile mob is not a healing target, so Heal must fall back to the Mystic.
skillRequest:FireServer("heal")
local healResult = waitForSkillResult(14, "self heal terminal result")
assert(healResult.applied == true and healResult.skillId == "heal" and healResult.isCritical == false)
local mysticHumanoid = if player.Character ~= nil then player.Character:FindFirstChildOfClass("Humanoid") else nil
assert(mysticHumanoid ~= nil and mysticHumanoid.Health > damagedHealth and mysticHumanoid.Health <= mysticHumanoid.MaxHealth)

skillRuntimeComplete:FireServer()
print("[PASS] authoritative SkillRequest runtime contract")
