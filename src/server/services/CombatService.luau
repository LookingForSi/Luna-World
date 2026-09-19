--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ActionRules = require(ReplicatedStorage.Shared.combat.ActionRules)
local AutoAttackRules = require(ReplicatedStorage.Shared.combat.AutoAttackRules)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local ProgressionRules = require(ReplicatedStorage.Shared.progression.ProgressionRules)
local CombatRules = require(ReplicatedStorage.Shared.combat.CombatRules)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local DamageRules = require(ReplicatedStorage.Shared.combat.DamageRules)
local ResourceRules = require(ReplicatedStorage.Shared.combat.ResourceRules)
local RemoteRequestRules = require(ReplicatedStorage.Shared.combat.RemoteRequestRules)
local CooldownRules = require(ReplicatedStorage.Shared.combat.CooldownRules)
local SkillRules = require(ReplicatedStorage.Shared.combat.SkillRules)
local SkillActionLifecycle = require(ReplicatedStorage.Shared.combat.SkillActionLifecycle)
local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)
local MobService = require(script.Parent.MobService)
local CombatEffectService = require(script.Parent.CombatEffectService)
local CombatPresentationService = require(script.Parent.CombatPresentationService)
local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)

local CombatService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local targetRequest = remotes:WaitForChild("TargetRequest") :: RemoteEvent
local attackRequest = remotes:WaitForChild("AttackRequest") :: RemoteEvent
local autoAttackModeRequest = remotes:WaitForChild("AutoAttackModeRequest") :: RemoteEvent
local skillRequest = remotes:WaitForChild("SkillRequest") :: RemoteEvent
local skillResult = remotes:WaitForChild("SkillResult") :: RemoteEvent

local function actorEntityId(player: Player): string
	return "player:" .. tostring(player.UserId)
end

local function publish(kind: CombatPresentationRules.Kind, actionId: string, player: Player, fields: CombatPresentationRules.Fields?): ()
	CombatPresentationService.publish(CombatPresentationRules.create(kind, actionId, actorEntityId(player), workspace:GetServerTimeNow(), fields))
end

local function reject(player: Player, fields: CombatPresentationRules.Fields): ()
	CombatPresentationService.publishToPlayer(player, CombatPresentationRules.create(
		"Result", HttpService:GenerateGUID(false), actorEntityId(player), workspace:GetServerTimeNow(), fields
	))
end

type PlayerCombatState = {
	readyAt: number,
	actionState: "Ready" | "Windup" | "Recovery",
	bufferedTargetId: string?,
	generation: number,
	archetypeId: string,
	stats: CombatTypes.CombatStatSnapshot,
	regenerationElapsed: number,
	cooldowns: CooldownRules.CooldownDeadlines,
	skillSlot: SkillActionLifecycle.Slot,
	autoAttackEnabled: boolean,
	autoAttackNextAttemptAt: number,
	pendingBasicActionId: string?,
}

local targetsByPlayer: { [Player]: string } = {}
local statesByPlayer: { [Player]: PlayerCombatState } = {}
local cooldownsByPlayer: { [Player]: CooldownRules.CooldownDeadlines } = {}
local characterDeathConnections: { [Player]: RBXScriptConnection } = {}
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
local targetLifecycleConnections: { [Player]: { RBXScriptConnection } } = {}
local lastTargetRequestAtByPlayer: { [Player]: number } = {}
local lastAttackRequestAtByPlayer: { [Player]: number } = {}
local lastSkillRequestAtByPlayer: { [Player]: number } = {}
local lastAutoAttackRequestAtByPlayer: { [Player]: number } = {}
local mobAttackReadyAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local started = false
local serviceConnections: { RBXScriptConnection } = {}
local regenerationSchedulerElapsed = 0
local criticalRandom = Random.new()

local TARGET_ATTRIBUTE = CombatConfig.SelectedTargetAttribute
local ACTION_STATE_ATTRIBUTE = CombatConfig.BasicActionStateAttribute
local READY_AT_ATTRIBUTE = CombatConfig.BasicAttackReadyAtAttribute
local BUFFERED_ATTRIBUTE = CombatConfig.BasicAttackBufferedAttribute
local AUTO_ATTACK_ATTRIBUTE = CombatConfig.AutoAttackEnabledAttribute
local ARCHETYPE_ATTRIBUTE = CombatConfig.ArchetypeAttribute
local RESOURCE_TYPE_ATTRIBUTE = CombatConfig.ResourceTypeAttribute
local RESOURCE_CURRENT_ATTRIBUTE = CombatConfig.ResourceCurrentAttribute
local RESOURCE_MAXIMUM_ATTRIBUTE = CombatConfig.ResourceMaximumAttribute
local COMBAT_POINTS_CURRENT_ATTRIBUTE = CombatConfig.CombatPointsCurrentAttribute
local COMBAT_POINTS_MAXIMUM_ATTRIBUTE = CombatConfig.CombatPointsMaximumAttribute
local SKILL_COOLDOWN_ATTRIBUTE_PREFIX = CombatConfig.SkillCooldownAttributePrefix

local getLivingCharacterRoot: (Player) -> BasePart?
local getLivingMobRoot: (Model) -> BasePart?

local function getArchetypeId(player: Player): string
	local requested = player:GetAttribute(ARCHETYPE_ATTRIBUTE)
	if typeof(requested) == "string" and ArchetypeDefinitions[requested] ~= nil then
		return requested
	end
	return "knight"
end

local function createStatSnapshot(archetypeId: string): CombatTypes.CombatStatSnapshot
	local archetype = ArchetypeDefinitions[archetypeId]
	local configured = CombatConfig.ArchetypeStats[archetypeId]
	assert(archetype ~= nil and configured ~= nil, "combat snapshot requires a known archetype")
	return {
		resource = ResourceRules.create(archetype.resourceType, configured.maximumResource),
		resourceRegenerationPerSecond = configured.resourceRegenerationPerSecond,
		physicalAttack = configured.physicalAttack,
		magicAttack = configured.magicAttack,
		basePhysicalDefense = configured.physicalDefense,
		physicalDefense = configured.physicalDefense,
		baseAttackSpeedMultiplier = configured.attackSpeedMultiplier,
		attackSpeedMultiplier = configured.attackSpeedMultiplier,
		criticalChance = configured.criticalChance,
		baseMovementSpeed = configured.movementSpeed,
		movementSpeed = configured.movementSpeed,
	}
end

local function replicateResource(player: Player, state: PlayerCombatState): ()
	player:SetAttribute(ARCHETYPE_ATTRIBUTE, state.archetypeId)
	player:SetAttribute(RESOURCE_TYPE_ATTRIBUTE, state.stats.resource.resourceType)
	player:SetAttribute(RESOURCE_CURRENT_ATTRIBUTE, state.stats.resource.current)
	player:SetAttribute(RESOURCE_MAXIMUM_ATTRIBUTE, state.stats.resource.maximum)
end

local function ensureCombatPoints(player: Player): ()
	local configuredMaximum = CombatConfig.CombatPointsDefaultMaximum
	local maximum = player:GetAttribute(COMBAT_POINTS_MAXIMUM_ATTRIBUTE)
	if typeof(maximum) ~= "number" or maximum <= 0 then
		maximum = configuredMaximum
		player:SetAttribute(COMBAT_POINTS_MAXIMUM_ATTRIBUTE, maximum)
	end
	local current = player:GetAttribute(COMBAT_POINTS_CURRENT_ATTRIBUTE)
	if typeof(current) ~= "number" then
		player:SetAttribute(COMBAT_POINTS_CURRENT_ATTRIBUTE, maximum)
	end
end

local function restoreCombatPoints(player: Player): ()
	ensureCombatPoints(player)
	local maximum = player:GetAttribute(COMBAT_POINTS_MAXIMUM_ATTRIBUTE)
	if typeof(maximum) == "number" then
		player:SetAttribute(COMBAT_POINTS_CURRENT_ATTRIBUTE, maximum)
	end
end

local function getSkillCooldownAttribute(skillId: string): string
	return SKILL_COOLDOWN_ATTRIBUTE_PREFIX .. skillId
end

local function replicateCooldowns(player: Player, state: PlayerCombatState): ()
	for skillId, definition in SkillDefinitions do
		player:SetAttribute(getSkillCooldownAttribute(skillId), state.cooldowns[definition.cooldownGroup] or 0)
	end
end

local function replicateState(player: Player, state: PlayerCombatState): ()
	player:SetAttribute(ACTION_STATE_ATTRIBUTE, state.actionState)
	player:SetAttribute(READY_AT_ATTRIBUTE, state.readyAt)
	player:SetAttribute(BUFFERED_ATTRIBUTE, state.bufferedTargetId ~= nil)
	player:SetAttribute(AUTO_ATTACK_ATTRIBUTE, state.autoAttackEnabled)
	replicateResource(player, state)
end

local function getState(player: Player): PlayerCombatState
	local state = statesByPlayer[player]
	if state == nil then
		local archetypeId = getArchetypeId(player)
		state = {
			readyAt = 0,
			actionState = "Ready",
			bufferedTargetId = nil,
			generation = 0,
			archetypeId = archetypeId,
			stats = createStatSnapshot(archetypeId),
			regenerationElapsed = 0,
			cooldowns = cooldownsByPlayer[player] or {},
			skillSlot = SkillActionLifecycle.createSlot(),
			autoAttackEnabled = false,
			autoAttackNextAttemptAt = 0,
			pendingBasicActionId = nil,
		}
		cooldownsByPlayer[player] = state.cooldowns
		statesByPlayer[player] = state
		replicateState(player, state)
		replicateCooldowns(player, state)
	end
	return state
end

local function getPlayerByCanonicalTargetId(targetId: string): Player?
	for _, candidate in Players:GetPlayers() do
		if targetId == "player:" .. tostring(candidate.UserId) then return candidate end
	end
	return nil
end

local function facePlayerTowardModel(player: Player, target: Model): ()
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") or targetRoot == nil or not targetRoot:IsA("BasePart") then return end
	local origin = root.Position
	local horizontalTarget = Vector3.new(targetRoot.Position.X, origin.Y, targetRoot.Position.Z)
	if (horizontalTarget - origin).Magnitude <= 0.001 then return end
	root.CFrame = CFrame.lookAt(origin, horizontalTarget)
end

local function resolveSkillTarget(
	player: Player,
	definition: CombatTypes.SkillDefinition,
	expectedCharacter: Model?
): CombatEffectService.EffectTarget?
	local character = player.Character
	local playerRoot = getLivingCharacterRoot(player)
	if playerRoot == nil or (expectedCharacter ~= nil and character ~= expectedCharacter) then return nil end

	if definition.targetType == "Self" then
		if not SkillRules.isTargetContextAllowed(definition.targetType, "Player", true) then return nil end
		return { kind = "Player", entityId = tostring(player.UserId), model = character :: Model }
	end
	if definition.targetType == "Friendly" then
		local effect = definition.effect
		local selectedTargetId = targetsByPlayer[player]
		local selectedPlayer: Player? = nil
		local selectedRoot: BasePart? = nil
		local selectedIsInRange = false
		if selectedTargetId ~= nil then
			selectedPlayer = getPlayerByCanonicalTargetId(selectedTargetId)
			selectedRoot = if selectedPlayer ~= nil then getLivingCharacterRoot(selectedPlayer) else nil
			selectedIsInRange = selectedRoot ~= nil and ActionRules.isWithinRange(
				playerRoot.Position,
				selectedRoot.Position,
				definition.range,
				CombatConfig.RangeTolerance
			)
		end
		local resolution = if effect.kind == "DirectHealing" then SkillRules.resolveFriendlyTarget(
			true,
			selectedPlayer ~= nil,
			selectedRoot ~= nil,
			selectedIsInRange,
			effect.selfCastWithoutFriendlyTarget
		) else nil
		if resolution == "Selected" and selectedTargetId ~= nil and selectedPlayer ~= nil and selectedPlayer.Character ~= nil then
			-- Every in-session player is friendly in v0.1; parties and PvP allegiance are outside this milestone.
			return { kind = "Player", entityId = selectedTargetId, model = selectedPlayer.Character }
		end
		if resolution == "Self" then
			if not SkillRules.isTargetContextAllowed(definition.targetType, "Player", true) then return nil end
			return { kind = "Player", entityId = "player:" .. tostring(player.UserId), model = character :: Model }
		end
		return nil
	end

	local selectedTargetId = targetsByPlayer[player]
	if selectedTargetId == nil then return nil end
	local target = MobService.getByEntityId(selectedTargetId)
	local targetRoot = if target ~= nil then getLivingMobRoot(target) else nil
	if target == nil or targetRoot == nil then return nil end
	if not SkillRules.isTargetContextAllowed(definition.targetType, "Mob", false) then return nil end
	local inRange = ActionRules.isWithinRange(playerRoot.Position, targetRoot.Position, definition.range, CombatConfig.RangeTolerance)
	-- Player actions auto-face a valid target; manual pre-facing is not an eligibility requirement.
	if not SkillRules.isEnemyTargetValid(selectedTargetId, selectedTargetId, true, true, inRange, true) then
		return nil
	end
	return { kind = "Mob", entityId = selectedTargetId, model = target }
end

local function acceptSkill(player: Player, definition: CombatTypes.SkillDefinition, now: number): ()
	local actionId = HttpService:GenerateGUID(false)
	local state = getState(player)
	if state.actionState == "Recovery" and now >= state.readyAt then
		state.actionState = "Ready"
		replicateState(player, state)
	end
	local target = resolveSkillTarget(player, definition, nil)
	local resourceAfterCost = ResourceRules.spend(state.stats.resource, definition.resourceType, definition.resourceCost)
	local cooldownReady = CooldownRules.isReady(state.cooldowns, definition.cooldownGroup, now)
	if not SkillRules.canAccept(
		state.actionState,
		cooldownReady,
		resourceAfterCost ~= nil,
		target ~= nil
	) then
		local targetReason: CombatPresentationRules.ReasonCode = "InvalidTarget"
		if target == nil then
			local selectedTargetId = targetsByPlayer[player]
			local selectedMob = if selectedTargetId ~= nil then MobService.getByEntityId(selectedTargetId) else nil
			local selectedPlayer = if selectedTargetId ~= nil then getPlayerByCanonicalTargetId(selectedTargetId) else nil
			local actorRoot = getLivingCharacterRoot(player)
			local selectedRoot = if selectedMob ~= nil
				then getLivingMobRoot(selectedMob)
				elseif selectedPlayer ~= nil then getLivingCharacterRoot(selectedPlayer)
				else nil
			if actorRoot ~= nil and selectedRoot ~= nil
				and (selectedRoot.Position - actorRoot.Position).Magnitude > definition.range + CombatConfig.RangeTolerance
			then
				targetReason = "OutOfRange"
			end
		end
		local reasonCode: CombatPresentationRules.ReasonCode = if state.actionState ~= "Ready"
			then "ForbiddenState"
			elseif not cooldownReady then "Cooldown"
			elseif resourceAfterCost == nil then "InsufficientResource"
			else targetReason
		reject(player, { skillId = definition.id, outcome = "Rejected", reasonCode = reasonCode })
		return
	end
	if not CombatEffectService.isImplemented(definition) then
		reject(player, { skillId = definition.id, outcome = "Rejected", reasonCode = "ForbiddenState" })
		return
	end

	if definition.requiresFacing and target.kind == "Mob" then
		facePlayerTowardModel(player, target.model)
	end

	local pendingAction = SkillActionLifecycle.begin(
		state.skillSlot,
		true,
		actionId,
		definition.id,
		target.entityId
	)
	if pendingAction == nil then
		reject(player, { skillId = definition.id, outcome = "Rejected", reasonCode = "ForbiddenState" })
		return
	end
	local acceptedCharacter = player.Character
	state.stats.resource = resourceAfterCost :: CombatTypes.CombatResource
	state.cooldowns = CooldownRules.start(state.cooldowns, definition.cooldownGroup, now, definition.cooldownSeconds)
	cooldownsByPlayer[player] = state.cooldowns
	replicateCooldowns(player, state)
	state.actionState = "Windup"
	state.bufferedTargetId = nil
	state.generation += 1
	replicateState(player, state)
	local generation = state.generation
	publish("Action", actionId, player, {
		targetEntityId = target.entityId,
		skillId = definition.id,
		presentationKey = definition.presentationKey,
		outcome = "Accepted",
	})

	task.delay(definition.windupSeconds, function()
		local currentState = statesByPlayer[player]
		if currentState == nil or currentState ~= state or currentState.generation ~= generation then return end
		local resolvedTarget = resolveSkillTarget(player, definition, acceptedCharacter)
		local effectResult: CombatEffectService.EffectResult = { applied = false }
		if resolvedTarget ~= nil and SkillRules.isAcceptedTargetIdentityCurrent(
			target.kind,
			target.entityId,
			target.model,
			resolvedTarget.kind,
			resolvedTarget.entityId,
			resolvedTarget.model
		) then
			if definition.requiresFacing and resolvedTarget.kind == "Mob" then
				facePlayerTowardModel(player, resolvedTarget.model)
			end
			local executionSucceeded, executedResult = pcall(
				CombatEffectService.execute,
				player,
				currentState.stats,
				definition,
				resolvedTarget,
				actionId
			)
			if executionSucceeded then
				effectResult = executedResult
			else
				warn(string.format("Skill effect failed for %s (%s): %s", player.Name, definition.id, tostring(executedResult)))
			end
		end
		local terminalResult = SkillActionLifecycle.finish(
			currentState.skillSlot,
			pendingAction,
			effectResult.applied,
			if effectResult.applied then nil else "ResolveFailed"
		)
		if statesByPlayer[player] == currentState and currentState.generation == generation then
			currentState.actionState = "Ready"
			replicateState(player, currentState)
		end
		if terminalResult ~= nil and player.Parent == Players then
			if effectResult.applied and effectResult.emitEffect ~= false then
				publish("Effect", terminalResult.actionId, player, {
					targetEntityId = terminalResult.targetEntityId,
					skillId = terminalResult.skillId,
					presentationKey = definition.presentationKey,
					outcome = "Applied",
					amount = effectResult.amount,
					isCritical = effectResult.isCritical,
					effectPhase = effectResult.effectPhase,
				})
			end
			publish("Result", terminalResult.actionId, player, {
				targetEntityId = terminalResult.targetEntityId,
				skillId = terminalResult.skillId,
				presentationKey = definition.presentationKey,
				outcome = if terminalResult.applied then "Applied" else (terminalResult.reason or "ResolveFailed"),
				amount = effectResult.amount,
				isCritical = effectResult.isCritical,
			})
			-- Only the server-created result is sent. Client-provided damage, target lists,
			-- timestamps and critical flags are impossible inputs to this executor.
			local delivered, deliveryError = pcall(skillResult.FireClient, skillResult, player, {
				actionId = terminalResult.actionId,
				skillId = terminalResult.skillId,
				targetEntityId = terminalResult.targetEntityId,
				applied = terminalResult.applied,
				reason = terminalResult.reason,
				amount = effectResult.amount,
				isCritical = effectResult.isCritical,
				presentationKey = definition.presentationKey,
			})
			if not delivered then
				warn(string.format("Skill result delivery failed for %s (%s): %s", player.Name, definition.id, tostring(deliveryError)))
			end
		end
	end)
end

local function onSkillRequest(player: Player, ...: unknown): ()
	local argumentCount = select("#", ...)
	local skillId = RemoteRequestRules.validateSkillRequest(argumentCount, (select(1, ...)))
	-- Malformed/extra payloads are silently dropped to avoid turning forged spam
	-- into a server-to-client presentation amplification path.
	if skillId == nil then return end
	-- A well-shaped request from a dead/respawning actor must not materialize a
	-- fresh state or overwrite the authoritative Dead replication.
	if getLivingCharacterRoot(player) == nil then return end
	local now = workspace:GetServerTimeNow()
	if ActionRules.isRequestRateLimited(now, lastSkillRequestAtByPlayer[player], CombatConfig.SkillRequestMinIntervalSeconds) then
		-- Rate-limited traffic is silent so hostile spam cannot amplify presentation events.
		return
	end
	lastSkillRequestAtByPlayer[player] = now
	local definition = SkillDefinitions[skillId]
	local archetypeId = getArchetypeId(player)
	local archetype = ArchetypeDefinitions[archetypeId]
	local decision = SkillRules.validateRequest(
		argumentCount,
		skillId,
		definition ~= nil,
		if definition ~= nil then definition.archetypeId else nil,
		archetypeId,
		definition ~= nil and archetype ~= nil and definition.id == archetype.basicAttackId
	)
	if not decision.accepted or definition == nil then
		reject(player, {
			outcome = "Rejected",
			reasonCode = "ForbiddenState",
		})
		return
	end
	local rawLevel = player:GetAttribute(ProgressionConfig.LevelAttribute)
	local actorLevel = if typeof(rawLevel) == "number" then rawLevel else 1
	if not ProgressionRules.isSkillUnlocked(definition.unlockLevel, actorLevel) then
		reject(player, {
			skillId = skillId,
			outcome = "Rejected",
			reasonCode = "ForbiddenState",
		})
		return
	end
	acceptSkill(player, definition, now)
end

local function getBasicAttackDefinition(state: PlayerCombatState): CombatTypes.SkillDefinition
	local archetype = ArchetypeDefinitions[state.archetypeId]
	assert(archetype ~= nil, "combat state has an unknown archetype")
	local definition = SkillDefinitions[archetype.basicAttackId]
	assert(definition ~= nil, "archetype has an unknown basic attack")
	return definition
end

local function getBasicAttackInterval(state: PlayerCombatState): number
	local definition = getBasicAttackDefinition(state)
	return DamageRules.getBasicAttackInterval(
		definition.cooldownSeconds,
		state.stats.attackSpeedMultiplier,
		CombatConfig.MinAttackSpeedMultiplier,
		CombatConfig.MaxAttackSpeedMultiplier
	)
end

local function setReplicatedTarget(player: Player, entityId: string?): ()
	player:SetAttribute(TARGET_ATTRIBUTE, entityId)
end

getLivingCharacterRoot = function(player: Player): BasePart?
	local character = player.Character
	if character == nil then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then return nil end
	return root
end

getLivingMobRoot = function(mob: Model): BasePart?
	local humanoid = mob:FindFirstChildOfClass("Humanoid")
	local root = mob:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then return nil end
	return root
end

local function cancelPendingAction(player: Player, discardSkillResult: boolean?): ()
	local state = statesByPlayer[player]
	if state == nil then return end
	local pendingSkill = state.skillSlot.pending
	local terminalResult: SkillActionLifecycle.Result? = nil
	local pendingBasicActionId = state.pendingBasicActionId
	state.pendingBasicActionId = nil
	if pendingSkill ~= nil then
		terminalResult = SkillActionLifecycle.finish(state.skillSlot, pendingSkill, false, "Canceled")
	end
	state.generation += 1
	state.actionState = "Ready"
	state.bufferedTargetId = nil
	state.readyAt = 0
	state.autoAttackEnabled = false
	state.autoAttackNextAttemptAt = 0
	replicateState(player, state)
	if pendingBasicActionId ~= nil and not discardSkillResult and player.Parent == Players then
		publish("Interruption", pendingBasicActionId, player, { outcome = "Canceled", reasonCode = "ForbiddenState" })
	end
	if terminalResult ~= nil and not discardSkillResult and player.Parent == Players then
		local definition = SkillDefinitions[terminalResult.skillId]
		publish("Interruption", terminalResult.actionId, player, {
			targetEntityId = terminalResult.targetEntityId,
			skillId = terminalResult.skillId,
			presentationKey = if definition ~= nil then definition.presentationKey else nil,
			outcome = terminalResult.reason or "Canceled",
			reasonCode = "ForbiddenState",
		})
		local delivered, deliveryError = pcall(skillResult.FireClient, skillResult, player, {
				actionId = terminalResult.actionId,
				skillId = terminalResult.skillId,
				targetEntityId = terminalResult.targetEntityId,
				applied = false,
				reason = terminalResult.reason,
				presentationKey = if definition ~= nil then definition.presentationKey else nil,
			})
		if not delivered then
			warn(string.format("Canceled skill result delivery failed for %s: %s", player.Name, tostring(deliveryError)))
		end
	end
end

local function clearTarget(player: Player): ()
	local connections = targetLifecycleConnections[player]
	if connections ~= nil then
		for _, connection in connections do connection:Disconnect() end
	end
	targetLifecycleConnections[player] = nil
	targetsByPlayer[player] = nil
	local state = statesByPlayer[player]
	if state ~= nil then
		state.bufferedTargetId = nil
		state.autoAttackEnabled = false
		state.autoAttackNextAttemptAt = 0
		replicateState(player, state)
	end
	setReplicatedTarget(player, nil)
end

local function clearPlayerState(player: Player, discardRuntimeState: boolean?): ()
	cancelPendingAction(player, discardRuntimeState)
	clearTarget(player)
	local state = statesByPlayer[player]
	CombatEffectService.clearPlayerEffects(player, if state ~= nil then state.stats else nil)
	statesByPlayer[player] = nil
	lastTargetRequestAtByPlayer[player] = nil
	lastAttackRequestAtByPlayer[player] = nil
	lastSkillRequestAtByPlayer[player] = nil
	lastAutoAttackRequestAtByPlayer[player] = nil
	if not SkillActionLifecycle.shouldPreserveCooldowns(discardRuntimeState) then cooldownsByPlayer[player] = nil end
end

local function getValidAttackTarget(player: Player, expectedTargetId: string, expectedCharacter: Model?): Model?
	local state = getState(player)
	local definition = getBasicAttackDefinition(state)
	local character = player.Character
	local playerRoot = getLivingCharacterRoot(player)
	local target = MobService.getByEntityId(expectedTargetId)
	local targetRoot = if target ~= nil then getLivingMobRoot(target) else nil
	local actorAlive = playerRoot ~= nil
	local targetAlive = target ~= nil and targetRoot ~= nil
	local characterMatches = expectedCharacter == nil or character == expectedCharacter
	if ActionRules.shouldInvalidatePlayerState(player.Parent == Players, actorAlive, characterMatches) then return nil end
	if target == nil or targetRoot == nil or playerRoot == nil then return nil end
	local inRange = CombatRules.canBasicAttack(
		playerRoot.Position,
		targetRoot.Position,
		targetAlive,
		definition.range + CombatConfig.RangeTolerance
	)
	if not ActionRules.canResolveAttack(expectedTargetId, targetsByPlayer[player], actorAlive, targetAlive, inRange, true) then return nil end
	return target
end

local function acceptAttack(player: Player, expectedTargetId: string): ()
	local state = getState(player)
	local initialTarget = getValidAttackTarget(player, expectedTargetId, nil)
	if state.actionState ~= "Ready" or initialTarget == nil then return end
	facePlayerTowardModel(player, initialTarget)
	local definition = getBasicAttackDefinition(state)
	local attackInterval = getBasicAttackInterval(state)
	-- Basic attacks are always free, but still pass through the authoritative resource boundary.
	local resourceAfterCost = ResourceRules.spend(state.stats.resource, definition.resourceType, definition.resourceCost)
	if resourceAfterCost == nil then return end

	local acceptedAt = workspace:GetServerTimeNow()
	local actionId = HttpService:GenerateGUID(false)
	state.pendingBasicActionId = actionId
	local acceptedCharacter = player.Character
	state.stats.resource = resourceAfterCost
	state.actionState = "Windup"
	state.readyAt = acceptedAt + attackInterval
	if state.autoAttackEnabled then state.autoAttackNextAttemptAt = state.readyAt end
	state.bufferedTargetId = nil
	state.generation += 1
	replicateState(player, state)
	local generation = state.generation
	publish("Action", actionId, player, {
		targetEntityId = expectedTargetId,
		skillId = definition.id,
		presentationKey = definition.presentationKey,
		outcome = "Accepted",
	})

	-- Resolve after the canonical wind-up; cooldown still starts at acceptance.
	task.delay(definition.windupSeconds, function()
		local currentState = statesByPlayer[player]
		if currentState == nil or currentState ~= state or currentState.generation ~= generation then return end
		local target = getValidAttackTarget(player, expectedTargetId, acceptedCharacter)
		local amount: number? = nil
		local isCritical: boolean? = nil
		if target ~= nil then
			facePlayerTowardModel(player, target)
			local attackPower = if definition.powerSource == "MagicAttack" then state.stats.magicAttack else state.stats.physicalAttack
			local damage = DamageRules.resolve(
				DamageRules.getBaseAmount(attackPower, definition.effect.magnitude),
				definition.effect.kind,
				definition.canCrit,
				state.stats.criticalChance,
				CombatConfig.CriticalDamageMultiplier,
				function(): number return criticalRandom:NextNumber() end
			)
			local applied = MobService.applyDamage(expectedTargetId, damage.amount, player)
			if applied then
				amount = damage.amount
				isCritical = damage.isCritical
			end
			if applied then
			publish("Effect", actionId, player, {
				targetEntityId = expectedTargetId,
				skillId = definition.id,
				presentationKey = definition.presentationKey,
				outcome = "Applied",
				amount = amount,
				isCritical = isCritical,
			})
			end
		end
		publish("Result", actionId, player, {
			targetEntityId = expectedTargetId,
			skillId = definition.id,
			presentationKey = definition.presentationKey,
			outcome = if amount ~= nil then "Applied" else "ResolveFailed",
			amount = amount,
			isCritical = isCritical,
		})
		if statesByPlayer[player] == currentState and currentState.generation == generation then
			currentState.pendingBasicActionId = nil
			currentState.actionState = "Recovery"
			replicateState(player, currentState)
		end
	end)

	task.delay(attackInterval, function()
		local currentState = statesByPlayer[player]
		if currentState == nil or currentState ~= state or currentState.generation ~= generation then return end
		currentState.actionState = "Ready"
		local bufferedTargetId = currentState.bufferedTargetId
		currentState.bufferedTargetId = nil
		replicateState(player, currentState)
		if bufferedTargetId ~= nil then acceptAttack(player, bufferedTargetId) end
	end)
end

local function onTargetRequest(player: Player, ...: unknown): ()
	local entityId = RemoteRequestRules.validateTargetRequest(select("#", ...), (select(1, ...)))
	if entityId == nil then return end
	-- The sole semantic clear command is one exact empty string. Other malformed
	-- payloads remain no-ops and cannot overload target selection behavior.
	if entityId == "" then
		-- Clearing is prompt and idempotent so death/UI cleanup cannot be delayed by selection spam.
		if targetsByPlayer[player] == nil then return end
		clearTarget(player)
		return
	end
	local now = workspace:GetServerTimeNow()
	if ActionRules.isRequestRateLimited(now, lastTargetRequestAtByPlayer[player], CombatConfig.TargetRequestMinIntervalSeconds) then return end
	lastTargetRequestAtByPlayer[player] = now
	local playerRoot = getLivingCharacterRoot(player)
	if string.sub(entityId, 1, 7) == "player:" then
		-- Task 15 will expose cross-platform player selection; this is its server-authoritative boundary.
		local selectedPlayer = getPlayerByCanonicalTargetId(entityId)
		local targetRoot = if selectedPlayer ~= nil then getLivingCharacterRoot(selectedPlayer) else nil
		if playerRoot == nil or selectedPlayer == nil or selectedPlayer == player or targetRoot == nil then return end
		if not CombatRules.canSelectTarget(playerRoot.Position, targetRoot.Position, true, CombatConfig.TargetSelectionRange) then return end
		clearTarget(player)
		targetsByPlayer[player] = entityId
		setReplicatedTarget(player, entityId)
		local selectedCharacter = selectedPlayer.Character
		local humanoid = if selectedCharacter ~= nil then selectedCharacter:FindFirstChildOfClass("Humanoid") else nil
		if humanoid ~= nil then
			local connections: { RBXScriptConnection } = {}
			table.insert(connections, humanoid.Died:Connect(function()
				if targetsByPlayer[player] == entityId then clearTarget(player) end
			end))
			table.insert(connections, selectedPlayer.CharacterAdded:Connect(function()
				if targetsByPlayer[player] == entityId then clearTarget(player) end
			end))
			if selectedCharacter ~= nil then
				table.insert(connections, selectedCharacter.AncestryChanged:Connect(function(_, parent)
					if parent == nil and targetsByPlayer[player] == entityId then clearTarget(player) end
				end))
			end
			targetLifecycleConnections[player] = connections
		end
		return
	end
	local target = MobService.getByEntityId(entityId)
	local targetRoot = if target ~= nil then getLivingMobRoot(target) else nil
	if playerRoot == nil or target == nil or targetRoot == nil then return end
	if not CombatRules.canSelectTarget(playerRoot.Position, targetRoot.Position, true, CombatConfig.TargetSelectionRange) then return end

	clearTarget(player)
	targetsByPlayer[player] = entityId
	setReplicatedTarget(player, entityId)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		local connections: { RBXScriptConnection } = {}
		table.insert(connections, humanoid.Died:Connect(function()
			if targetsByPlayer[player] == entityId then clearTarget(player) end
		end))
		table.insert(connections, target.AncestryChanged:Connect(function(_, parent)
			if parent == nil and targetsByPlayer[player] == entityId then clearTarget(player) end
		end))
		targetLifecycleConnections[player] = connections
	end
end

local function onAttackRequest(player: Player, ...: unknown): ()
	-- The Milestone 1 contract has no payload. This explicitly rejects legacy booleans and extra arguments.
	if not RemoteRequestRules.validateAttackRequest(select("#", ...)) then return end
	-- Check lifecycle before rate bookkeeping and before any path can call getState.
	if getLivingCharacterRoot(player) == nil then return end
	local now = workspace:GetServerTimeNow()
	if ActionRules.isRequestRateLimited(now, lastAttackRequestAtByPlayer[player], CombatConfig.AttackRequestMinIntervalSeconds) then
		reject(player, { outcome = "Rejected", reasonCode = "RateLimited" })
		return
	end
	lastAttackRequestAtByPlayer[player] = now
	local targetId = targetsByPlayer[player]
	if targetId == nil or getValidAttackTarget(player, targetId, nil) == nil then
		local target = if targetId ~= nil then MobService.getByEntityId(targetId) else nil
		local targetRoot = if target ~= nil then getLivingMobRoot(target) else nil
		local playerRoot = getLivingCharacterRoot(player)
		local reasonCode: CombatPresentationRules.ReasonCode = if playerRoot ~= nil and targetRoot ~= nil
			and not CombatRules.canBasicAttack(
				playerRoot.Position,
				targetRoot.Position,
				true,
				getBasicAttackDefinition(getState(player)).range + CombatConfig.RangeTolerance
			)
			then "OutOfRange"
			else "InvalidTarget"
		reject(player, { outcome = "Rejected", reasonCode = reasonCode })
		return
	end

	local state = getState(player)
	if state.actionState == "Recovery" and now >= state.readyAt then
		state.actionState = "Ready"
		replicateState(player, state)
	end
	local timing = ActionRules.evaluateTiming(now, state.readyAt, CombatConfig.InputBufferSeconds, state.bufferedTargetId ~= nil)
	if timing.kind == "Accept" and state.actionState == "Ready" then
		acceptAttack(player, targetId)
	elseif timing.kind == "Buffer" and state.actionState == "Recovery" then
		state.bufferedTargetId = targetId
		replicateState(player, state)
	else
		reject(player, { targetEntityId = targetId, outcome = "Rejected", reasonCode = "Cooldown" })
	end
end

local function onAutoAttackModeRequest(player: Player, ...: unknown): ()
	local argumentCount = select("#", ...)
	local requestedEnabled = RemoteRequestRules.validateAutoAttackRequest(argumentCount, (select(1, ...)))
	if requestedEnabled == nil then return end
	local existingState = statesByPlayer[player]
	if requestedEnabled == (existingState ~= nil and existingState.autoAttackEnabled) then return end

	-- Explicit off is always prompt and cheap, including under hostile request traffic.
	if not requestedEnabled then
		if existingState == nil then return end
		existingState.autoAttackEnabled = false
		existingState.autoAttackNextAttemptAt = 0
		replicateState(player, existingState)
		return
	end

	local now = workspace:GetServerTimeNow()
	if ActionRules.isRequestRateLimited(
		now,
		lastAutoAttackRequestAtByPlayer[player],
		CombatConfig.AutoAttackRequestMinIntervalSeconds
	) then return end
	lastAutoAttackRequestAtByPlayer[player] = now
	local targetId = targetsByPlayer[player]
	local actorAlive = getLivingCharacterRoot(player) ~= nil
	local target = if targetId ~= nil then MobService.getByEntityId(targetId) else nil
	local hasLivingMobTarget = target ~= nil and getLivingMobRoot(target) ~= nil
	local decision = AutoAttackRules.validateRequest(argumentCount, requestedEnabled, actorAlive, hasLivingMobTarget)
	if not decision.accepted then return end
	local state = statesByPlayer[player]
	if state == nil then
		if decision.enabled ~= true then return end
		state = getState(player)
	end

	state.autoAttackEnabled = decision.enabled == true
	state.autoAttackNextAttemptAt = if state.autoAttackEnabled then now else 0
	-- Enabling only schedules server-owned attempts. It never selects, moves toward, or invokes a skill.
	replicateState(player, state)
end

local function bindCharacter(player: Player, character: Model): ()
	clearPlayerState(player)
	local oldConnection = characterDeathConnections[player]
	if oldConnection ~= nil then oldConnection:Disconnect() end
	characterDeathConnections[player] = nil
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if player.Character == character and humanoid ~= nil and humanoid:IsA("Humanoid") then
		characterDeathConnections[player] = humanoid.Died:Connect(function() clearPlayerState(player) end)
		getState(player)
	end
end

local function onPlayerAdded(player: Player): ()
	if characterAddedConnections[player] ~= nil then return end
	setReplicatedTarget(player, nil)
	ensureCombatPoints(player)
	replicateState(player, getState(player))
	characterAddedConnections[player] = player.CharacterAdded:Connect(function(character) bindCharacter(player, character) end)
	if player.Character ~= nil then bindCharacter(player, player.Character) end
end

-- Server-only entry point used by MobAIService. The AI proposes an action; combat
-- owns acceptance, timing, revalidation, mitigation, and the authoritative result.
function CombatService.requestMobBasicAttack(
	mob: Model,
	target: Player,
	definition: CombatTypes.MobDefinition
): boolean
	local now = workspace:GetServerTimeNow()
	local humanoid = mob:FindFirstChildOfClass("Humanoid")
	local root = mob:FindFirstChild("HumanoidRootPart")
	local targetRoot = getLivingCharacterRoot(target)
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") or targetRoot == nil then return false end
	if mob:GetAttribute(CombatConfig.MobStunnedAttribute) == true then return false end
	if now < (mobAttackReadyAt[mob] or 0) then return false end
	if (targetRoot.Position - root.Position).Magnitude > definition.attackRange + CombatConfig.RangeTolerance then return false end

	mobAttackReadyAt[mob] = now + definition.attackIntervalSeconds
	local actionId = HttpService:GenerateGUID(false)
	local rawMobEntityId = mob:GetAttribute("EntityId")
	local mobEntityId = if typeof(rawMobEntityId) == "string" and rawMobEntityId ~= ""
		then "mob:" .. rawMobEntityId
		else "mob:" .. definition.id
	local previousGeneration = mob:GetAttribute(CombatConfig.MobActionGenerationAttribute)
	local generation = if typeof(previousGeneration) == "number" then previousGeneration + 1 else 1
	mob:SetAttribute(CombatConfig.MobActionGenerationAttribute, generation)
	mob:SetAttribute(CombatConfig.MobActionStateAttribute, "Windup")
	mob:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, true)
	task.delay(definition.attackWindupSeconds, function()
		if mob.Parent == nil or target.Parent ~= Players then return end
		if mob:GetAttribute(CombatConfig.MobActionGenerationAttribute) ~= generation then return end
		local currentHumanoid = mob:FindFirstChildOfClass("Humanoid")
		local currentRoot = mob:FindFirstChild("HumanoidRootPart")
		local currentTargetRoot = getLivingCharacterRoot(target)
		if currentHumanoid == nil or currentHumanoid.Health <= 0 or currentRoot == nil or not currentRoot:IsA("BasePart") or currentTargetRoot == nil then return end
		if (currentTargetRoot.Position - currentRoot.Position).Magnitude > definition.attackRange + CombatConfig.RangeTolerance then return end
		local targetHumanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if targetHumanoid == nil then return end
		local targetState = getState(target)
		local damage = math.max(1, definition.basicAttackDamage - targetState.stats.physicalDefense)
		targetHumanoid:TakeDamage(damage)
		CombatPresentationService.publishToPlayer(target, CombatPresentationRules.create(
			"Result",
			actionId,
			mobEntityId,
			workspace:GetServerTimeNow(),
			{
				targetEntityId = actorEntityId(target),
				presentationKey = "mob_basic_attack",
				outcome = "Applied",
				amount = damage,
				isCritical = false,
				definitionId = definition.id,
			}
		))
		mob:SetAttribute(CombatConfig.MobActionStateAttribute, "Recovery")
		mob:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, nil)
	end)
	task.delay(definition.attackIntervalSeconds, function()
		if mob.Parent ~= nil and mob:GetAttribute(CombatConfig.MobActionGenerationAttribute) == generation then
			mob:SetAttribute(CombatConfig.MobActionStateAttribute, nil)
			mob:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, nil)
		end
	end)
	return true
end

-- RespawnService owns player lifecycle timing; combat owns authoritative cleanup.
function CombatService.handlePlayerDeath(player: Player): ()
	clearPlayerState(player)
	player:SetAttribute(ACTION_STATE_ATTRIBUTE, "Dead")
	player:SetAttribute(BUFFERED_ATTRIBUTE, false)
	player:SetAttribute(AUTO_ATTACK_ATTRIBUTE, false)
	publish("Death", HttpService:GenerateGUID(false), player, { outcome = "Dead" })
end

function CombatService.handlePlayerRespawn(player: Player, character: Model): ()
	if player.Character ~= character then return end
	clearPlayerState(player)
	local state = getState(player)
	state.stats.resource = ResourceRules.restore(state.stats.resource, state.stats.resource.maximum)
	state.regenerationElapsed = 0
	replicateState(player, state)
	restoreCombatPoints(player)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then humanoid.Health = humanoid.MaxHealth end
	publish("Respawn", HttpService:GenerateGUID(false), player, { outcome = "Respawned" })
end

function CombatService.start(): ()
	if started then return end
	started = true
	table.insert(serviceConnections, targetRequest.OnServerEvent:Connect(onTargetRequest))
	table.insert(serviceConnections, attackRequest.OnServerEvent:Connect(onAttackRequest))
	table.insert(serviceConnections, autoAttackModeRequest.OnServerEvent:Connect(onAutoAttackModeRequest))
	table.insert(serviceConnections, skillRequest.OnServerEvent:Connect(onSkillRequest))
	table.insert(serviceConnections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(serviceConnections, Players.PlayerRemoving:Connect(function(player)
		clearPlayerState(player, true)
		local deathConnection = characterDeathConnections[player]
		if deathConnection ~= nil then deathConnection:Disconnect() end
		characterDeathConnections[player] = nil
		local addedConnection = characterAddedConnections[player]
		if addedConnection ~= nil then addedConnection:Disconnect() end
		characterAddedConnections[player] = nil
	end))
	for _, player in Players:GetPlayers() do onPlayerAdded(player) end
	table.insert(serviceConnections, RunService.Heartbeat:Connect(function(deltaTime)
		local now = workspace:GetServerTimeNow()
		for player, state in statesByPlayer do
			if state.autoAttackEnabled and now >= state.autoAttackNextAttemptAt then
				local targetId = targetsByPlayer[player]
				local actorAlive = getLivingCharacterRoot(player) ~= nil
				local target = if targetId ~= nil then MobService.getByEntityId(targetId) else nil
				local hasLivingMobTarget = target ~= nil and getLivingMobRoot(target) ~= nil
				if AutoAttackRules.shouldStop(player.Parent == Players, actorAlive, player.Character ~= nil, hasLivingMobTarget) then
					state.autoAttackEnabled = false
					state.autoAttackNextAttemptAt = 0
					replicateState(player, state)
				elseif AutoAttackRules.shouldAttempt(now, state.autoAttackNextAttemptAt, state.actionState)
					and targetId ~= nil
					and getValidAttackTarget(player, targetId, nil) ~= nil
				then
					acceptAttack(player, targetId)
				else
					state.autoAttackNextAttemptAt = AutoAttackRules.nextAttemptAt(
						now,
						state.readyAt,
						CombatConfig.AutoAttackRetryIntervalSeconds
					)
				end
			end
		end
		regenerationSchedulerElapsed += deltaTime
		if regenerationSchedulerElapsed < CombatConfig.ResourceRegenerationIntervalSeconds then return end
		local elapsed = regenerationSchedulerElapsed
		regenerationSchedulerElapsed = 0
		for player, state in statesByPlayer do
			local regenerated, remainder = ResourceRules.stepRegeneration(
				state.stats.resource,
				state.stats.resourceRegenerationPerSecond,
				state.regenerationElapsed,
				elapsed,
				CombatConfig.ResourceRegenerationIntervalSeconds,
				player.Parent == Players and getLivingCharacterRoot(player) ~= nil
			)
			state.regenerationElapsed = remainder
			if regenerated.current ~= state.stats.resource.current then
				state.stats.resource = regenerated
				replicateResource(player, state)
			end
		end
	end))
end

function CombatService.stop(): ()
	if not started then return end
	started = false
	regenerationSchedulerElapsed = 0
	for _, connection in serviceConnections do connection:Disconnect() end
	table.clear(serviceConnections)
	for _, state in statesByPlayer do
		state.generation += 1
	end
	for _, connection in characterDeathConnections do connection:Disconnect() end
	for _, connection in characterAddedConnections do connection:Disconnect() end
	for _, connections in targetLifecycleConnections do
		for _, connection in connections do connection:Disconnect() end
	end
	for _, player in Players:GetPlayers() do
		local state = statesByPlayer[player]
		CombatEffectService.clearPlayerEffects(player, if state ~= nil then state.stats else nil)
		player:SetAttribute(TARGET_ATTRIBUTE, nil)
		player:SetAttribute(ACTION_STATE_ATTRIBUTE, nil)
		player:SetAttribute(READY_AT_ATTRIBUTE, nil)
		player:SetAttribute(BUFFERED_ATTRIBUTE, nil)
		player:SetAttribute(AUTO_ATTACK_ATTRIBUTE, nil)
		player:SetAttribute(RESOURCE_TYPE_ATTRIBUTE, nil)
		player:SetAttribute(RESOURCE_CURRENT_ATTRIBUTE, nil)
		player:SetAttribute(RESOURCE_MAXIMUM_ATTRIBUTE, nil)
		player:SetAttribute(COMBAT_POINTS_CURRENT_ATTRIBUTE, nil)
		player:SetAttribute(COMBAT_POINTS_MAXIMUM_ATTRIBUTE, nil)
		player:SetAttribute(ARCHETYPE_ATTRIBUTE, nil)
		for skillId in SkillDefinitions do
			player:SetAttribute(getSkillCooldownAttribute(skillId), nil)
		end
	end
	CombatEffectService.stop()
	table.clear(targetsByPlayer)
	table.clear(statesByPlayer)
	table.clear(cooldownsByPlayer)
	table.clear(characterDeathConnections)
	table.clear(characterAddedConnections)
	table.clear(targetLifecycleConnections)
	table.clear(lastAttackRequestAtByPlayer)
	table.clear(lastTargetRequestAtByPlayer)
	table.clear(lastSkillRequestAtByPlayer)
	table.clear(lastAutoAttackRequestAtByPlayer)
	table.clear(mobAttackReadyAt)
end

-- Studio-only archetype switch seam. StudioDebugService delegates here so the
-- old authoritative state is torn down before the selected archetype is written.
function CombatService._setArchetypeForStudio(player: Player, archetypeId: string): boolean
	assert(RunService:IsStudio(), "Studio archetype switch is unavailable outside Studio")
	if player.Parent ~= Players or ArchetypeDefinitions[archetypeId] == nil then return false end
	clearPlayerState(player, true)
	player:SetAttribute(ARCHETYPE_ATTRIBUTE, archetypeId)
	player:LoadCharacter()
	return true
end

-- Test-project-only server seam. It is unavailable in live servers and is never
-- reachable through a client RemoteEvent.
function CombatService._setResourceForTest(player: Player, current: number): ()
	assert(
		RunService:IsStudio() and ReplicatedStorage:FindFirstChild("TestRemotes") ~= nil,
		"combat test seam is available only in the Studio test project"
	)
	local state = statesByPlayer[player]
	assert(state ~= nil, "combat test seam requires initialized player state")
	assert(current >= 0 and current <= state.stats.resource.maximum, "combat test resource is out of bounds")
	state.stats.resource = {
		resourceType = state.stats.resource.resourceType,
		current = current,
		maximum = state.stats.resource.maximum,
	}
	replicateResource(player, state)
end

return CombatService
