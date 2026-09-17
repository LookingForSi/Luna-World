--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local DamageRules = require(ReplicatedStorage.Shared.combat.DamageRules)
local EffectRules = require(ReplicatedStorage.Shared.combat.EffectRules)
local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local MobService = require(script.Parent.MobService)

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
}

local criticalRandom = Random.new()
type StunState = { generation: number, ancestryConnection: RBXScriptConnection }
type StanceState = {
	defenseIncrease: number,
	movementSpeedMultiplier: number,
	character: Model,
	stats: CombatTypes.CombatStatSnapshot,
}
local stunStates: { [Model]: StunState } = {}
local stanceStates: { [Player]: StanceState } = {}

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
	state.ancestryConnection:Disconnect()
	if model.Parent ~= nil then
		model:SetAttribute(CombatConfig.MobStunnedAttribute, nil)
		model:SetAttribute(CombatConfig.MobStunnedUntilAttribute, nil)
		if restoreMovement then MobService.applyCalculatedMovement(model) end
	end
end

local function applyStun(model: Model, durationSeconds: number): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then return false end
	local existingStun = stunStates[model]
	local generation = if existingStun ~= nil then existingStun.generation + 1 else 1
	local ancestryConnection = if existingStun ~= nil
		then existingStun.ancestryConnection
		else model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then clearStun(model, nil, false) end
		end)
	stunStates[model] = { generation = generation, ancestryConnection = ancestryConnection }
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
		or definition.effect.kind == "ShieldBash"
		or definition.effect.kind == "DefenseStance"
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
	stats.movementSpeed = values.movementSpeed
	if stance ~= nil and player.Character == stance.character and stance.character.Parent ~= nil then
		local humanoid = stance.character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then humanoid.WalkSpeed = values.movementSpeed end
	elseif player.Character ~= nil then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then humanoid.WalkSpeed = values.movementSpeed end
	end
end

function CombatEffectService.recomputePlayerModifiers(player: Player, stats: CombatTypes.CombatStatSnapshot): ()
	applyPlayerCalculatedStats(player, stats, stanceStates[player])
end

function CombatEffectService.clearPlayerEffects(player: Player, stats: CombatTypes.CombatStatSnapshot?): ()
	local stance = stanceStates[player]
	if stance == nil then return end
	stanceStates[player] = nil
	if stats ~= nil then
		applyPlayerCalculatedStats(player, stats, nil)
	end
	if stance.character.Parent ~= nil then
		stance.character:SetAttribute(CombatConfig.DefenseStanceActiveAttribute, nil)
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
end

function CombatEffectService.execute(
	actor: Player,
	stats: CombatTypes.CombatStatSnapshot,
	definition: CombatTypes.SkillDefinition,
	target: EffectTarget
): EffectResult
	local effect = definition.effect
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
			}
			target.model:SetAttribute(CombatConfig.DefenseStanceActiveAttribute, true)
		else
			stanceStates[actor] = nil
			target.model:SetAttribute(CombatConfig.DefenseStanceActiveAttribute, nil)
		end
		applyPlayerCalculatedStats(actor, stats, stanceStates[actor])
		return { applied = true }
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
	if not MobService.applyDamage(target.entityId, damage.amount, actor) then
		return { applied = false }
	end
	if effect.kind == "ShieldBash" then
		local rank = getMobRank(target.model)
		if rank ~= nil then
			local decision = EffectRules.resolveShieldBash(
				rank,
				effect.stunsOrdinaryMobs,
				effect.interruptsEligibleImmuneMobs,
				target.model:GetAttribute(CombatConfig.MobActionInterruptibleAttribute) == true
			)
			if decision.shouldStun then
				applyStun(target.model, effect.durationSeconds)
			elseif decision.shouldInterrupt then
				interruptMobAction(target.model)
			end
		end
	end
	return { applied = true, amount = damage.amount, isCritical = damage.isCritical }
end

return table.freeze(CombatEffectService)
