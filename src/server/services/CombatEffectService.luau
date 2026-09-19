--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local DamageRules = require(ReplicatedStorage.Shared.combat.DamageRules)
local EffectRules = require(ReplicatedStorage.Shared.combat.EffectRules)
local SkillRules = require(ReplicatedStorage.Shared.combat.SkillRules)
local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local MobService = require(script.Parent.MobService)
local CombatPresentationService = require(script.Parent.CombatPresentationService)
local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)

local CombatEffectService = {}

export type EffectTarget = {
	kind: "Mob" | "Player",
	entityId: string,
	model: Model,
}

export type EffectResult = {
	applied: boolean,
	amount: number?,
	isCritical: boolean?,
	effectPhase: ("Started" | "Ended")?,
	emitEffect: boolean?,
}

type AreaTarget = { entityId: string, model: Model }
type AreaQuery = (Vector3, number, number) -> { AreaTarget }
type AreaDamageApplication = (string, number, Player) -> boolean

local criticalRandom = Random.new()
type StunState = {
	generation: number,
	ancestryConnection: RBXScriptConnection,
	deathConnection: RBXScriptConnection,
	actor: Player, actionId: string, targetEntityId: string, skillId: string, presentationKey: string,
}
type StanceState = {
	defenseIncrease: number,
	movementSpeedMultiplier: number,
	character: Model,
	stats: CombatTypes.CombatStatSnapshot,
	actionId: string, skillId: string, presentationKey: string,
}
type RapidShotState = {
	attackSpeedIncrease: number,
	character: Model,
	stats: CombatTypes.CombatStatSnapshot,
	actionId: string, skillId: string, presentationKey: string,
}
type SlowState = {
	ancestryConnection: RBXScriptConnection,
	deathConnection: RBXScriptConnection,
	actor: Player, actionId: string, targetEntityId: string, skillId: string, presentationKey: string,
}

local function publishEnded(actor: Player, actionId: string, targetEntityId: string, skillId: string, presentationKey: string): ()
	CombatPresentationService.publish(CombatPresentationRules.create("Effect", actionId, "player:" .. tostring(actor.UserId), workspace:GetServerTimeNow(), {
		targetEntityId = targetEntityId, skillId = skillId, presentationKey = presentationKey,
		outcome = "Ended", effectPhase = "Ended",
	}))
end
local stunStates: { [Model]: StunState } = {}
local stanceStates: { [Player]: StanceState } = {}
local rapidShotStates: { [Player]: RapidShotState } = {}
local slowStates: { [Model]: SlowState } = {}

local function getMobRank(model: Model): CombatTypes.MobRank?
	local mobId = model:GetAttribute("MobId")
	if typeof(mobId) ~= "string" then return nil end
	for _, definition in MobDefinitions do
		if definition.id == mobId then return definition.rank end
	end
	return nil
end

local function clearStun(model: Model, expectedGeneration: number?, restoreMovement: boolean): ()
	local state = stunStates[model]
	if state == nil or (expectedGeneration ~= nil and state.generation ~= expectedGeneration) then return end
	stunStates[model] = nil
	publishEnded(state.actor, state.actionId, state.targetEntityId, state.skillId, state.presentationKey)
	state.ancestryConnection:Disconnect()
	state.deathConnection:Disconnect()
	if model.Parent ~= nil then
		model:SetAttribute(CombatConfig.MobStunnedAttribute, nil)
		model:SetAttribute(CombatConfig.MobStunnedUntilAttribute, nil)
		if restoreMovement then MobService.applyCalculatedMovement(model) end
	end
end

local function applyStun(model: Model, durationSeconds: number, actor: Player, actionId: string, targetEntityId: string, skillId: string, presentationKey: string): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then return false end
	local existingStun = stunStates[model]
	if existingStun ~= nil then
		publishEnded(existingStun.actor, existingStun.actionId, existingStun.targetEntityId, existingStun.skillId, existingStun.presentationKey)
	end
	local generation = if existingStun ~= nil then existingStun.generation + 1 else 1
	local ancestryConnection = if existingStun ~= nil
		then existingStun.ancestryConnection
		else model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then clearStun(model, nil, false) end
		end)
	local deathConnection = if existingStun ~= nil
		then existingStun.deathConnection
		else humanoid.Died:Connect(function()
			clearStun(model, nil, false)
		end)
	stunStates[model] = {
		generation = generation,
		ancestryConnection = ancestryConnection,
		deathConnection = deathConnection,
		actor = actor, actionId = actionId, targetEntityId = targetEntityId, skillId = skillId, presentationKey = presentationKey,
	}
	local actionGeneration = model:GetAttribute(CombatConfig.MobActionGenerationAttribute)
	model:SetAttribute(
		CombatConfig.MobActionGenerationAttribute,
		EffectRules.invalidateMobActionGeneration(if typeof(actionGeneration) == "number" then actionGeneration else nil)
	)
	model:SetAttribute(CombatConfig.MobActionStateAttribute, nil)
	model:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, nil)
	model:SetAttribute(CombatConfig.MobStunnedAttribute, true)
	model:SetAttribute(CombatConfig.MobStunnedUntilAttribute, workspace:GetServerTimeNow() + durationSeconds)
	MobService.applyCalculatedMovement(model)
	task.delay(durationSeconds, function()
		clearStun(model, generation, true)
	end)
	return true
end

local function interruptMobAction(model: Model): boolean
	if model:GetAttribute(CombatConfig.MobActionInterruptibleAttribute) ~= true then return false end
	local generation = model:GetAttribute(CombatConfig.MobActionGenerationAttribute)
	model:SetAttribute(
		CombatConfig.MobActionGenerationAttribute,
		EffectRules.invalidateMobActionGeneration(if typeof(generation) == "number" then generation else nil)
	)
	model:SetAttribute(CombatConfig.MobActionStateAttribute, nil)
	model:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, nil)
	return true
end

function CombatEffectService.isImplemented(definition: CombatTypes.SkillDefinition): boolean
	return definition.effect.kind == "DirectDamage"
		or definition.effect.kind == "DirectHealing"
		or definition.effect.kind == "AreaDamage"
		or definition.effect.kind == "ShieldBash"
		or definition.effect.kind == "DefenseStance"
		or definition.effect.kind == "AttackSpeedBuff"
		or definition.effect.kind == "MovementSlow"
end

local function applyPlayerCalculatedStats(
	player: Player,
	stats: CombatTypes.CombatStatSnapshot,
	stance: StanceState?
): ()
	local values = EffectRules.resolveDefenseStance(
		stats.basePhysicalDefense,
		stats.baseMovementSpeed,
		stats.attackSpeedMultiplier,
		if stance ~= nil then stance.defenseIncrease else 0,
		if stance ~= nil then stance.movementSpeedMultiplier else 1,
		stance ~= nil
	)
	stats.physicalDefense = values.physicalDefense
	local hostileMovement = player:GetAttribute(CombatConfig.HostileMovementMultiplierAttribute)
	local hostileAttackSpeed = player:GetAttribute(CombatConfig.HostileAttackSpeedMultiplierAttribute)
	local movementMultiplier = if typeof(hostileMovement) == "number" then math.clamp(hostileMovement, 0.1, 1) else 1
	local attackSpeedMultiplier = if typeof(hostileAttackSpeed) == "number" then math.clamp(hostileAttackSpeed, 0.1, 1) else 1
	stats.movementSpeed = values.movementSpeed * movementMultiplier
	local rapidShot = rapidShotStates[player]
	local friendlyAttackSpeed = EffectRules.resolveAttackSpeed(
		stats.baseAttackSpeedMultiplier,
		if rapidShot ~= nil then rapidShot.attackSpeedIncrease else 0,
		CombatConfig.MaxAttackSpeedMultiplier,
		rapidShot ~= nil
	)
	stats.attackSpeedMultiplier = math.max(CombatConfig.MinAttackSpeedMultiplier, friendlyAttackSpeed * attackSpeedMultiplier)
	if stance ~= nil and player.Character == stance.character and stance.character.Parent ~= nil then
		local humanoid = stance.character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then humanoid.WalkSpeed = stats.movementSpeed end
	elseif player.Character ~= nil then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then humanoid.WalkSpeed = stats.movementSpeed end
	end
end

local function clearRapidShot(player: Player, expectedState: RapidShotState?): ()
	local state = rapidShotStates[player]
	if expectedState ~= nil and not EffectRules.isCurrentEffectToken(state, expectedState, player.Character == expectedState.character) then
		return
	end
	if state == nil then return end
	rapidShotStates[player] = nil
	publishEnded(player, state.actionId, "player:" .. tostring(player.UserId), state.skillId, state.presentationKey)
	if state.character.Parent ~= nil then state.character:SetAttribute(CombatConfig.RapidShotActiveAttribute, nil) end
	applyPlayerCalculatedStats(player, state.stats, stanceStates[player])
end

local function clearSlow(model: Model, expectedState: SlowState?, restoreMovement: boolean): ()
	local state = slowStates[model]
	if expectedState ~= nil and not EffectRules.isCurrentEffectToken(state, expectedState, slowStates[model] == expectedState) then
		return
	end
	if state == nil then return end
	slowStates[model] = nil
	publishEnded(state.actor, state.actionId, state.targetEntityId, state.skillId, state.presentationKey)
	state.ancestryConnection:Disconnect()
	state.deathConnection:Disconnect()
	model:SetAttribute(CombatConfig.MobMovementSlowAttribute, nil)
	model:SetAttribute(CombatConfig.MobMovementSlowUntilAttribute, nil)
	if model.Parent ~= nil then
		if restoreMovement then MobService.applyCalculatedMovement(model) end
	end
end

local function applySlow(model: Model, magnitude: number, durationSeconds: number, actor: Player, actionId: string, targetEntityId: string, skillId: string, presentationKey: string): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then return false end
	local existing = slowStates[model]
	if existing ~= nil then
		publishEnded(existing.actor, existing.actionId, existing.targetEntityId, existing.skillId, existing.presentationKey)
	end
	local ancestryConnection = if existing ~= nil
		then existing.ancestryConnection
		else model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then clearSlow(model, slowStates[model], false) end
		end)
	local deathConnection = if existing ~= nil
		then existing.deathConnection
		else humanoid.Died:Connect(function() clearSlow(model, slowStates[model], false) end)
	local state: SlowState = {
		ancestryConnection = ancestryConnection,
		deathConnection = deathConnection,
		actor = actor, actionId = actionId, targetEntityId = targetEntityId, skillId = skillId, presentationKey = presentationKey,
	}
	slowStates[model] = state
	model:SetAttribute(CombatConfig.MobMovementSlowAttribute, magnitude)
	model:SetAttribute(CombatConfig.MobMovementSlowUntilAttribute, workspace:GetServerTimeNow() + durationSeconds)
	MobService.applyCalculatedMovement(model)
	task.delay(durationSeconds, function()
		clearSlow(model, state, true)
	end)
	return true
end

function CombatEffectService.recomputePlayerModifiers(player: Player, stats: CombatTypes.CombatStatSnapshot): ()
	applyPlayerCalculatedStats(player, stats, stanceStates[player])
end

function CombatEffectService.clearPlayerEffects(player: Player, stats: CombatTypes.CombatStatSnapshot?): ()
	local stance = stanceStates[player]
	local rapidShot = rapidShotStates[player]
	stanceStates[player] = nil
	rapidShotStates[player] = nil
	if stats ~= nil then applyPlayerCalculatedStats(player, stats, nil) end
	if stance ~= nil and stance.character.Parent ~= nil then
		stance.character:SetAttribute(CombatConfig.DefenseStanceActiveAttribute, nil)
	end
	if stance ~= nil then
		publishEnded(player, stance.actionId, "player:" .. tostring(player.UserId), stance.skillId, stance.presentationKey)
	end
	if rapidShot ~= nil and rapidShot.character.Parent ~= nil then
		rapidShot.character:SetAttribute(CombatConfig.RapidShotActiveAttribute, nil)
	end
	if rapidShot ~= nil then
		publishEnded(player, rapidShot.actionId, "player:" .. tostring(player.UserId), rapidShot.skillId, rapidShot.presentationKey)
	end
end

function CombatEffectService.stop(): ()
	local stunnedModels = {}
	for model in stunStates do table.insert(stunnedModels, model) end
	for _, model in stunnedModels do clearStun(model, nil, true) end
	local stancePlayers = {}
	for player in stanceStates do table.insert(stancePlayers, player) end
	for _, player in stancePlayers do
		local stance = stanceStates[player]
		CombatEffectService.clearPlayerEffects(player, if stance ~= nil then stance.stats else nil)
	end
	local rapidPlayers = {}
	for player in rapidShotStates do table.insert(rapidPlayers, player) end
	for _, player in rapidPlayers do
		local rapidShot = rapidShotStates[player]
		CombatEffectService.clearPlayerEffects(player, if rapidShot ~= nil then rapidShot.stats else nil)
	end
	local slowedModels = {}
	for model in slowStates do table.insert(slowedModels, model) end
	for _, model in slowedModels do clearSlow(model, slowStates[model], true) end
end

function CombatEffectService.executeAreaDamage(
	actor: Player,
	stats: CombatTypes.CombatStatSnapshot,
	definition: CombatTypes.SkillDefinition,
	centerModel: Model,
	queryTargets: AreaQuery?,
	applyDamage: AreaDamageApplication?,
	roll: (() -> number)?
): EffectResult
	local effect = definition.effect
	if effect.kind ~= "AreaDamage" then return { applied = false } end
	local centerRoot = centerModel:FindFirstChild("HumanoidRootPart")
	if centerRoot == nil or not centerRoot:IsA("BasePart") then return { applied = false } end
	local authoritativeQuery = queryTargets or MobService.getLivingTargetsInRadius
	local authoritativeApplication = applyDamage or MobService.applyDamage
	local targets = authoritativeQuery(centerRoot.Position, effect.radius, effect.maximumTargets)
	local appliedCount = 0
	local totalAmount = 0
	local anyCritical = false
	for _, areaTarget in targets do
		local damage = DamageRules.resolve(
			DamageRules.getBaseAmount(stats.magicAttack, effect.magnitude),
			effect.kind,
			definition.canCrit,
			stats.criticalChance,
			CombatConfig.CriticalDamageMultiplier,
			roll or function(): number return criticalRandom:NextNumber() end
		)
		local applied = false
		local appliedAmount: number? = nil
		if applyDamage ~= nil then
			applied = authoritativeApplication(areaTarget.entityId, damage.amount, actor)
			appliedAmount = if applied then damage.amount else nil
		else
			applied, appliedAmount = MobService.applyDamage(areaTarget.entityId, damage.amount, actor, "Magic")
		end
		if applied then
			appliedCount += 1
			totalAmount += appliedAmount or damage.amount
			anyCritical = anyCritical or damage.isCritical
		end
	end
	return { applied = appliedCount > 0, amount = if appliedCount > 0 then totalAmount else nil, isCritical = anyCritical }
end

function CombatEffectService.execute(
	actor: Player,
	stats: CombatTypes.CombatStatSnapshot,
	definition: CombatTypes.SkillDefinition,
	target: EffectTarget,
	actionId: string?
): EffectResult
	local presentationActionId = actionId or ("effect:" .. definition.id)
	local effect = definition.effect
	if effect.kind == "DirectHealing" then
		if target.kind ~= "Player" then return { applied = false } end
		local humanoid = target.model:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then return { applied = false } end
		local healedHealth = SkillRules.resolveHealing(
			humanoid.Health,
			humanoid.MaxHealth,
			DamageRules.getBaseAmount(stats.magicAttack, effect.magnitude),
			humanoid.Health > 0
		)
		if healedHealth == nil then return { applied = false } end
		local amount = healedHealth - humanoid.Health
		humanoid.Health = healedHealth
		return { applied = true, amount = amount, isCritical = false }
	end
	if effect.kind == "AreaDamage" then
		if target.kind ~= "Mob" then return { applied = false } end
		return CombatEffectService.executeAreaDamage(actor, stats, definition, target.model)
	end
	if effect.kind == "DefenseStance" then
		if target.kind ~= "Player" or target.model ~= actor.Character then return { applied = false } end
		local humanoid = target.model:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or humanoid.Health <= 0 then return { applied = false } end
		local existing = stanceStates[actor]
		if existing == nil then
			stanceStates[actor] = {
				defenseIncrease = effect.magnitude,
				movementSpeedMultiplier = effect.movementSpeedMultiplier,
				character = target.model,
				stats = stats,
				actionId = presentationActionId, skillId = definition.id, presentationKey = definition.presentationKey,
			}
			target.model:SetAttribute(CombatConfig.DefenseStanceActiveAttribute, true)
		else
			publishEnded(actor, existing.actionId, target.entityId, existing.skillId, existing.presentationKey)
			stanceStates[actor] = nil
			target.model:SetAttribute(CombatConfig.DefenseStanceActiveAttribute, nil)
		end
		applyPlayerCalculatedStats(actor, stats, stanceStates[actor])
		return { applied = true, effectPhase = if existing == nil then "Started" else nil, emitEffect = existing == nil }
	end
	if effect.kind == "AttackSpeedBuff" then
		if target.kind ~= "Player" or target.model ~= actor.Character then return { applied = false } end
		local humanoid = target.model:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or humanoid.Health <= 0 then return { applied = false } end
		local existingRapidShot = rapidShotStates[actor]
		if existingRapidShot ~= nil then
			publishEnded(actor, existingRapidShot.actionId, "player:" .. tostring(actor.UserId), existingRapidShot.skillId, existingRapidShot.presentationKey)
		end
		local state: RapidShotState = {
			attackSpeedIncrease = effect.magnitude,
			character = target.model,
			stats = stats,
			actionId = presentationActionId, skillId = definition.id, presentationKey = definition.presentationKey,
		}
		rapidShotStates[actor] = state
		target.model:SetAttribute(CombatConfig.RapidShotActiveAttribute, true)
		applyPlayerCalculatedStats(actor, stats, stanceStates[actor])
		task.delay(effect.durationSeconds, function() clearRapidShot(actor, state) end)
		return { applied = true, effectPhase = "Started" }
	end
	if effect.kind == "MovementSlow" then
		if target.kind ~= "Mob" then return { applied = false } end
		local applied = applySlow(target.model, effect.magnitude, effect.durationSeconds, actor, presentationActionId, target.entityId, definition.id, definition.presentationKey)
		if applied then
			-- A debuff is a hostile action even when it deals no damage.
			MobService.registerHostileAction(target.entityId, actor)
		end
		return { applied = applied, effectPhase = if applied then "Started" else nil }
	end

	if target.kind ~= "Mob" or (effect.kind ~= "DirectDamage" and effect.kind ~= "ShieldBash") then
		return { applied = false }
	end

	local attackPower = if definition.powerSource == "MagicAttack" then stats.magicAttack else stats.physicalAttack
	local damage = DamageRules.resolve(
		DamageRules.getBaseAmount(attackPower, effect.magnitude),
		effect.kind,
		definition.canCrit,
		stats.criticalChance,
		CombatConfig.CriticalDamageMultiplier,
		function(): number return criticalRandom:NextNumber() end
	)
	local damageType: CombatTypes.MobDamageType = if definition.powerSource == "MagicAttack" then "Magic" else "Physical"
	local applied, appliedAmount = MobService.applyDamage(target.entityId, damage.amount, actor, damageType)
	if not applied then
		return { applied = false }
	end
	local resolvedAmount = appliedAmount or damage.amount
	if effect.kind == "ShieldBash" then
		local startedTemporaryEffect = false
		local rank = getMobRank(target.model)
		if rank ~= nil then
			local decision = EffectRules.resolveShieldBash(
				rank,
				effect.stunsOrdinaryMobs,
				effect.interruptsEligibleImmuneMobs,
				target.model:GetAttribute(CombatConfig.MobActionInterruptibleAttribute) == true
			)
			if decision.shouldStun then
				startedTemporaryEffect = applyStun(target.model, effect.durationSeconds, actor, presentationActionId, target.entityId, definition.id, definition.presentationKey)
			elseif decision.shouldInterrupt then
				interruptMobAction(target.model)
			end
		end
		return { applied = true, amount = resolvedAmount, isCritical = damage.isCritical, effectPhase = if startedTemporaryEffect then "Started" else nil }
	end
	return { applied = true, amount = resolvedAmount, isCritical = damage.isCritical }
end

return table.freeze(CombatEffectService)
