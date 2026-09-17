--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ActionRules = require(ReplicatedStorage.Shared.combat.ActionRules)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatRules = require(ReplicatedStorage.Shared.combat.CombatRules)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local DamageRules = require(ReplicatedStorage.Shared.combat.DamageRules)
local ResourceRules = require(ReplicatedStorage.Shared.combat.ResourceRules)
local CooldownRules = require(ReplicatedStorage.Shared.combat.CooldownRules)
local SkillRules = require(ReplicatedStorage.Shared.combat.SkillRules)
local SkillActionLifecycle = require(ReplicatedStorage.Shared.combat.SkillActionLifecycle)
local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)
local MobService = require(script.Parent.MobService)
local CombatEffectService = require(script.Parent.CombatEffectService)

local CombatService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local targetRequest = remotes:WaitForChild("TargetRequest") :: RemoteEvent
local attackRequest = remotes:WaitForChild("AttackRequest") :: RemoteEvent
local skillRequest = remotes:WaitForChild("SkillRequest") :: RemoteEvent
local skillResult = remotes:WaitForChild("SkillResult") :: RemoteEvent

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
}

local targetsByPlayer: { [Player]: string } = {}
local statesByPlayer: { [Player]: PlayerCombatState } = {}
local cooldownsByPlayer: { [Player]: CooldownRules.CooldownDeadlines } = {}
local characterDeathConnections: { [Player]: RBXScriptConnection } = {}
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
local targetLifecycleConnections: { [Player]: { RBXScriptConnection } } = {}
local lastAttackRequestAtByPlayer: { [Player]: number } = {}
local lastSkillRequestAtByPlayer: { [Player]: number } = {}
local started = false
local serviceConnections: { RBXScriptConnection } = {}
local regenerationSchedulerElapsed = 0
local criticalRandom = Random.new()

local TARGET_ATTRIBUTE = CombatConfig.SelectedTargetAttribute
local ACTION_STATE_ATTRIBUTE = CombatConfig.BasicActionStateAttribute
local READY_AT_ATTRIBUTE = CombatConfig.BasicAttackReadyAtAttribute
local BUFFERED_ATTRIBUTE = CombatConfig.BasicAttackBufferedAttribute
local ARCHETYPE_ATTRIBUTE = CombatConfig.ArchetypeAttribute
local RESOURCE_TYPE_ATTRIBUTE = CombatConfig.ResourceTypeAttribute
local RESOURCE_CURRENT_ATTRIBUTE = CombatConfig.ResourceCurrentAttribute
local RESOURCE_MAXIMUM_ATTRIBUTE = CombatConfig.ResourceMaximumAttribute
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
	replicateResource(player, state)
	replicateCooldowns(player, state)
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
		}
		cooldownsByPlayer[player] = state.cooldowns
		statesByPlayer[player] = state
		replicateState(player, state)
	end
	return state
end

local function getPlayerByCanonicalTargetId(targetId: string): Player?
	for _, candidate in Players:GetPlayers() do
		if targetId == "player:" .. tostring(candidate.UserId) then return candidate end
	end
	return nil
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
	local isFacing = not definition.requiresFacing or ActionRules.isFacing(
		playerRoot.Position,
		playerRoot.CFrame.LookVector,
		targetRoot.Position,
		CombatConfig.FacingArcDegrees
	)
	if not SkillRules.isEnemyTargetValid(selectedTargetId, selectedTargetId, true, true, inRange, isFacing) then
		return nil
	end
	return { kind = "Mob", entityId = selectedTargetId, model = target }
end

local function acceptSkill(player: Player, definition: CombatTypes.SkillDefinition, now: number): ()
	local state = getState(player)
	if state.actionState == "Recovery" and now >= state.readyAt then
		state.actionState = "Ready"
		replicateState(player, state)
	end
	local target = resolveSkillTarget(player, definition, nil)
	local resourceAfterCost = ResourceRules.spend(state.stats.resource, definition.resourceType, definition.resourceCost)
	if not SkillRules.canAccept(
		state.actionState,
		CooldownRules.isReady(state.cooldowns, definition.cooldownGroup, now),
		resourceAfterCost ~= nil,
		target ~= nil
	) then return end
	if not CombatEffectService.isImplemented(definition) then return end

	local actionId = HttpService:GenerateGUID(false)
	local pendingAction = SkillActionLifecycle.begin(
		state.skillSlot,
		true,
		actionId,
		definition.id,
		target.entityId
	)
	if pendingAction == nil then return end
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
			local executionSucceeded, executedResult = pcall(
				CombatEffectService.execute,
				player,
				currentState.stats,
				definition,
				resolvedTarget
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
	local skillId = select(1, ...)
	local state = getState(player)
	local definition = if typeof(skillId) == "string" then SkillDefinitions[skillId] else nil
	local archetype = ArchetypeDefinitions[state.archetypeId]
	local decision = SkillRules.validateRequest(
		argumentCount,
		skillId,
		definition ~= nil,
		if definition ~= nil then definition.archetypeId else nil,
		state.archetypeId,
		definition ~= nil and archetype ~= nil and definition.id == archetype.basicAttackId
	)
	if not decision.accepted or definition == nil then return end

	local now = workspace:GetServerTimeNow()
	if ActionRules.isRequestRateLimited(now, lastSkillRequestAtByPlayer[player], CombatConfig.SkillRequestMinIntervalSeconds) then
		return
	end
	lastSkillRequestAtByPlayer[player] = now
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
	if pendingSkill ~= nil then
		terminalResult = SkillActionLifecycle.finish(state.skillSlot, pendingSkill, false, "Canceled")
	end
	state.generation += 1
	state.actionState = "Ready"
	state.bufferedTargetId = nil
	state.readyAt = 0
	replicateState(player, state)
	if terminalResult ~= nil and not discardSkillResult and player.Parent == Players then
		local definition = SkillDefinitions[terminalResult.skillId]
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
	lastAttackRequestAtByPlayer[player] = nil
	lastSkillRequestAtByPlayer[player] = nil
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
	local isFacing = ActionRules.isFacing(
		playerRoot.Position,
		playerRoot.CFrame.LookVector,
		targetRoot.Position,
		CombatConfig.FacingArcDegrees
	)
	if not ActionRules.canResolveAttack(expectedTargetId, targetsByPlayer[player], actorAlive, targetAlive, inRange, isFacing) then return nil end
	return target
end

local function acceptAttack(player: Player, expectedTargetId: string): ()
	local state = getState(player)
	if state.actionState ~= "Ready" or getValidAttackTarget(player, expectedTargetId, nil) == nil then return end
	local definition = getBasicAttackDefinition(state)
	local attackInterval = getBasicAttackInterval(state)
	-- Basic attacks are always free, but still pass through the authoritative resource boundary.
	local resourceAfterCost = ResourceRules.spend(state.stats.resource, definition.resourceType, definition.resourceCost)
	if resourceAfterCost == nil then return end

	local acceptedAt = workspace:GetServerTimeNow()
	local acceptedCharacter = player.Character
	state.stats.resource = resourceAfterCost
	state.actionState = "Windup"
	state.readyAt = acceptedAt + attackInterval
	state.bufferedTargetId = nil
	state.generation += 1
	replicateState(player, state)
	local generation = state.generation

	-- Resolve after the canonical wind-up; cooldown still starts at acceptance.
	task.delay(definition.windupSeconds, function()
		local currentState = statesByPlayer[player]
		if currentState == nil or currentState ~= state or currentState.generation ~= generation then return end
		local target = getValidAttackTarget(player, expectedTargetId, acceptedCharacter)
		if target ~= nil then
			local attackPower = if definition.powerSource == "MagicAttack" then state.stats.magicAttack else state.stats.physicalAttack
			local damage = DamageRules.resolve(
				DamageRules.getBaseAmount(attackPower, definition.effect.magnitude),
				definition.effect.kind,
				definition.canCrit,
				state.stats.criticalChance,
				CombatConfig.CriticalDamageMultiplier,
				function(): number return criticalRandom:NextNumber() end
			)
			MobService.applyDamage(expectedTargetId, damage.amount, player)
		end
		if statesByPlayer[player] == currentState and currentState.generation == generation then
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

local function onTargetRequest(player: Player, entityId: unknown): ()
	if typeof(entityId) ~= "string" then return end
	local playerRoot = getLivingCharacterRoot(player)
	if string.sub(entityId, 1, 7) == "player:" then
		-- Task 15 will expose cross-platform player selection; this is its server-authoritative boundary.
		local selectedPlayer = getPlayerByCanonicalTargetId(entityId)
		local targetRoot = if selectedPlayer ~= nil then getLivingCharacterRoot(selectedPlayer) else nil
		if playerRoot == nil or selectedPlayer == nil or targetRoot == nil then return end
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
	if select("#", ...) ~= 0 then return end
	local now = workspace:GetServerTimeNow()
	if ActionRules.isRequestRateLimited(now, lastAttackRequestAtByPlayer[player], CombatConfig.AttackRequestMinIntervalSeconds) then
		return
	end
	lastAttackRequestAtByPlayer[player] = now
	local targetId = targetsByPlayer[player]
	if targetId == nil or getValidAttackTarget(player, targetId, nil) == nil then return end

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
	end
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
	replicateState(player, getState(player))
	characterAddedConnections[player] = player.CharacterAdded:Connect(function(character) bindCharacter(player, character) end)
	if player.Character ~= nil then bindCharacter(player, player.Character) end
end

function CombatService.start(): ()
	if started then return end
	started = true
	table.insert(serviceConnections, targetRequest.OnServerEvent:Connect(onTargetRequest))
	table.insert(serviceConnections, attackRequest.OnServerEvent:Connect(onAttackRequest))
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
		player:SetAttribute(RESOURCE_TYPE_ATTRIBUTE, nil)
		player:SetAttribute(RESOURCE_CURRENT_ATTRIBUTE, nil)
		player:SetAttribute(RESOURCE_MAXIMUM_ATTRIBUTE, nil)
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
	table.clear(lastSkillRequestAtByPlayer)
end

return CombatService
