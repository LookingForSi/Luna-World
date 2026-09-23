--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local MobAbilityDefinitions = require(ReplicatedStorage.Shared.definitions.MobAbilityDefinitions)
local MobService = require(script.Parent.MobService)
local CombatCoordinator = require(script.Parent.Parent.features.combat.CombatCoordinator)
local CombatPresentationService = require(script.Parent.CombatPresentationService)
local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local DamageRules = require(ReplicatedStorage.Shared.combat.DamageRules)

local MobAbilityService = {}

local abilityCooldownsByMob: { [Model]: { [string]: number } } = setmetatable({}, { __mode = "k" }) :: any
local basicReadyAtByMob: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local nextActionReadyAtByMob: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local abilityCursorByMob: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local buffGenerationByMob: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local poisonGenerationByPlayer: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
local criticalRandom = Random.new()
local started = false

local function actorEntityId(mob: Model, definition: CombatTypes.MobDefinition): string
	local entityId = mob:GetAttribute("EntityId")
	return if typeof(entityId) == "string" and entityId ~= "" then "mob:" .. entityId else "mob:" .. definition.id
end

local function targetEntityId(player: Player): string
	return "player:" .. tostring(player.UserId)
end

local function livingPlayerHumanoid(player: Player): Humanoid?
	if player.Parent ~= Players then return nil end
	local character = player.Character
	if character == nil then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then return nil end
	return humanoid
end

local function livingPlayerRoot(player: Player): BasePart?
	local humanoid = livingPlayerHumanoid(player)
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or root == nil or not root:IsA("BasePart") then return nil end
	return root
end

local function livingMobParts(mob: Model): (Humanoid?, BasePart?)
	local humanoid = mob:FindFirstChildOfClass("Humanoid")
	local root = mob:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then return nil, nil end
	return humanoid, root
end

local function outgoingMultiplier(mob: Model): number
	local value = mob:GetAttribute(CombatConfig.MobOutgoingDamageMultiplierAttribute)
	return if typeof(value) == "number" then math.max(0, value) else 1
end

local function resolveIncomingDamage(
	target: Player,
	rawDamage: number,
	damageType: CombatTypes.MobDamageType
): number?
	local stats = CombatCoordinator.getPlayerCombatStats(target)
	if stats == nil then return nil end
	local defense = if damageType == "Physical" then stats.physicalDefense else 0
	if damageType == "Physical" then
		-- Flat subtraction collapsed early mob hits to the 1-damage floor as soon
		-- as starter defense matched their raw damage. Proportional mitigation
		-- preserves the tanking value of defense without making low-level mobs
		-- harmless.
		local mitigated = rawDamage / (1 + defense * CombatConfig.PhysicalDefenseMitigationPerPoint)
		return math.max(1, math.floor(mitigated + 0.5))
	end
	return math.max(1, math.floor(rawDamage + 0.5))
end

local function publishToTarget(
	target: Player,
	kind: CombatPresentationRules.Kind,
	actionId: string,
	actorId: string,
	fields: CombatPresentationRules.Fields
): ()
	CombatPresentationService.publishToPlayer(target, CombatPresentationRules.create(
		kind,
		actionId,
		actorId,
		workspace:GetServerTimeNow(),
		fields
	))
end

local function applyDamage(
	mob: Model,
	target: Player,
	definition: CombatTypes.MobDefinition,
	damageType: CombatTypes.MobDamageType,
	rawDamage: number,
	actionId: string,
	presentationKey: string,
	abilityId: string?
): number?
	local humanoid = livingPlayerHumanoid(target)
	if humanoid == nil then return nil end

	local criticalChance = math.clamp(definition.criticalChance or 0, 0, 1)
	local criticalMultiplier = math.max(
		1,
		definition.criticalDamageMultiplier or CombatConfig.CriticalDamageMultiplier
	)
	local rolled = DamageRules.resolve(
		rawDamage * outgoingMultiplier(mob),
		"DirectDamage",
		criticalChance > 0,
		criticalChance,
		criticalMultiplier,
		function() return criticalRandom:NextNumber() end
	)
	local damage = resolveIncomingDamage(target, rolled.amount, damageType)
	if damage == nil then return nil end
	CombatCoordinator.selectAttackerIfNoTarget(target, mob)
	humanoid:TakeDamage(damage)
	publishToTarget(target, "Result", actionId, actorEntityId(mob, definition), {
		targetEntityId = targetEntityId(target),
		presentationKey = presentationKey,
		outcome = "Applied",
		amount = damage,
		isCritical = rolled.isCritical,
		definitionId = definition.id,
		skillId = abilityId,
	})
	return damage
end

local function setMobDamageBuff(mob: Model, multiplier: number, durationSeconds: number): ()
	local humanoid = mob:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then return end
	local generation = (buffGenerationByMob[mob] or 0) + 1
	buffGenerationByMob[mob] = generation
	local current = outgoingMultiplier(mob)
	mob:SetAttribute(CombatConfig.MobOutgoingDamageMultiplierAttribute, math.max(current, multiplier))
	task.delay(durationSeconds, function()
		if mob.Parent ~= nil and buffGenerationByMob[mob] == generation then
			mob:SetAttribute(CombatConfig.MobOutgoingDamageMultiplierAttribute, 1)
		end
	end)
end

local function applyAllyDamageBuff(
	mob: Model,
	target: Player,
	definition: CombatTypes.MobDefinition,
	ability: CombatTypes.MobAbilityDefinition
): ()
	local _, sourceRoot = livingMobParts(mob)
	if sourceRoot == nil then return end
	local radius = ability.radius or 0
	local multiplier = ability.damageMultiplier or 1
	local duration = ability.durationSeconds or 0
	for _, candidate in MobService.getAll() do
		local candidateDefinition = MobService.getDefinition(candidate)
		local candidateHumanoid, candidateRoot = livingMobParts(candidate)
		if candidateDefinition ~= nil
			and candidateDefinition.faction == definition.faction
			and candidateHumanoid ~= nil
			and candidateRoot ~= nil
			and (candidateRoot.Position - sourceRoot.Position).Magnitude <= radius
		then
			setMobDamageBuff(candidate, multiplier, duration)
			if ability.callsAllies == true then
				local entityId = candidate:GetAttribute("EntityId")
				if typeof(entityId) == "string" and entityId ~= "" then
					MobService.registerHostileAction(entityId, target)
				end
			end
		end
	end
end

local function applyPoison(
	mob: Model,
	target: Player,
	definition: CombatTypes.MobDefinition,
	ability: CombatTypes.MobAbilityDefinition,
	actionId: string
): ()
	local character = target.Character
	if character == nil then return end
	local generation = (poisonGenerationByPlayer[target] or 0) + 1
	poisonGenerationByPlayer[target] = generation
	local tickDamage = ability.tickDamage or 0
	local interval = ability.tickIntervalSeconds or 1
	local duration = ability.durationSeconds or 0
	local tickCount = math.max(0, math.floor(duration / interval))
	for tick = 1, tickCount do
		task.delay(interval * tick, function()
			if poisonGenerationByPlayer[target] ~= generation or target.Parent ~= Players or target.Character ~= character then return end
			local humanoid = livingPlayerHumanoid(target)
			if humanoid == nil then return end
			local damage = resolveIncomingDamage(target, tickDamage * outgoingMultiplier(mob), ability.damageType)
			if damage == nil then return end
			humanoid:TakeDamage(damage)
			publishToTarget(target, "Effect", actionId, actorEntityId(mob, definition), {
				targetEntityId = targetEntityId(target),
				presentationKey = ability.presentationKey,
				outcome = "Applied",
				amount = damage,
				isCritical = false,
				definitionId = definition.id,
				skillId = ability.id,
				effectPhase = "Started",
			})
			if tick == tickCount and poisonGenerationByPlayer[target] == generation then
				poisonGenerationByPlayer[target] = nil
			end
		end)
	end
end

local function applyAreaDamage(
	mob: Model,
	definition: CombatTypes.MobDefinition,
	ability: CombatTypes.MobAbilityDefinition,
	actionId: string
): boolean
	local _, root = livingMobParts(mob)
	if root == nil then return false end
	local applied = false
	local radius = ability.radius or ability.range
	for _, candidate in Players:GetPlayers() do
		local candidateRoot = livingPlayerRoot(candidate)
		if candidateRoot ~= nil and (candidateRoot.Position - root.Position).Magnitude <= radius then
			if applyDamage(mob, candidate, definition, ability.damageType, ability.damage, actionId, ability.presentationKey, ability.id) ~= nil then
				applied = true
			end
		end
	end
	return applied
end

local function abilityEligible(
	mob: Model,
	definition: CombatTypes.MobDefinition,
	ability: CombatTypes.MobAbilityDefinition,
	distance: number,
	now: number
): boolean
	if distance > ability.range then return false end
	local cooldowns = abilityCooldownsByMob[mob]
	if cooldowns ~= nil and now < (cooldowns[ability.id] or 0) then return false end
	if ability.healthBelowFraction ~= nil then
		local humanoid = mob:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or humanoid.MaxHealth <= 0 or humanoid.Health / humanoid.MaxHealth > ability.healthBelowFraction then
			return false
		end
	end
	return true
end

local function selectAbility(
	mob: Model,
	definition: CombatTypes.MobDefinition,
	distance: number,
	now: number
): CombatTypes.MobAbilityDefinition?
	local count = #definition.abilityIds
	if count == 0 then return nil end
	local start = ((abilityCursorByMob[mob] or 0) % count) + 1
	for offset = 0, count - 1 do
		local index = ((start + offset - 1) % count) + 1
		local ability = MobAbilityDefinitions[definition.abilityIds[index]]
		if ability ~= nil and abilityEligible(mob, definition, ability, distance, now) then
			abilityCursorByMob[mob] = index
			return ability
		end
	end
	return nil
end

local function beginAction(
	mob: Model,
	definition: CombatTypes.MobDefinition,
	target: Player,
	ability: CombatTypes.MobAbilityDefinition
): boolean
	local now = workspace:GetServerTimeNow()
	if now < (nextActionReadyAtByMob[mob] or 0) then return false end
	local humanoid, root = livingMobParts(mob)
	local targetRoot = livingPlayerRoot(target)
	if humanoid == nil or root == nil or targetRoot == nil then return false end
	if (targetRoot.Position - root.Position).Magnitude > ability.range + CombatConfig.RangeTolerance then return false end

	local cooldowns = abilityCooldownsByMob[mob]
	if cooldowns == nil then cooldowns = {}; abilityCooldownsByMob[mob] = cooldowns end
	cooldowns[ability.id] = now + ability.cooldownSeconds
	nextActionReadyAtByMob[mob] = now + math.max(0.8, ability.windupSeconds + 0.45)

	local actionId = HttpService:GenerateGUID(false)
	local previousGeneration = mob:GetAttribute(CombatConfig.MobActionGenerationAttribute)
	local generation = if typeof(previousGeneration) == "number" then previousGeneration + 1 else 1
	mob:SetAttribute(CombatConfig.MobActionGenerationAttribute, generation)
	mob:SetAttribute(CombatConfig.MobActionStateAttribute, "Windup")
	mob:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, true)
	publishToTarget(target, "Action", actionId, actorEntityId(mob, definition), {
		targetEntityId = targetEntityId(target),
		skillId = ability.id,
		presentationKey = ability.presentationKey,
		outcome = "Accepted",
		definitionId = definition.id,
	})

	task.delay(ability.windupSeconds, function()
		if mob.Parent == nil or target.Parent ~= Players then return end
		if mob:GetAttribute(CombatConfig.MobActionGenerationAttribute) ~= generation then return end
		local currentHumanoid, currentRoot = livingMobParts(mob)
		local currentTargetRoot = livingPlayerRoot(target)
		if currentHumanoid == nil or currentRoot == nil or currentTargetRoot == nil then return end
		if (currentTargetRoot.Position - currentRoot.Position).Magnitude > ability.range + CombatConfig.RangeTolerance then return end

		if ability.kind == "DirectDamage" then
			applyDamage(mob, target, definition, ability.damageType, ability.damage, actionId, ability.presentationKey, ability.id)
		elseif ability.kind == "AreaDamage" then
			applyAreaDamage(mob, definition, ability, actionId)
		elseif ability.kind == "DamageOverTime" then
			local amount = applyDamage(mob, target, definition, ability.damageType, ability.damage, actionId, ability.presentationKey, ability.id)
			if amount ~= nil then applyPoison(mob, target, definition, ability, actionId) end
		elseif ability.kind == "Crippling" then
			local amount = applyDamage(mob, target, definition, ability.damageType, ability.damage, actionId, ability.presentationKey, ability.id)
			if amount ~= nil then
				local movement = ability.movementMultiplier or 1
				local attackSpeed = ability.attackSpeedMultiplier or 1
				CombatCoordinator.applyMobDebuff(target, movement, attackSpeed, ability.durationSeconds or 0)
			end
		elseif ability.kind == "AllyDamageBuff" then
			applyAllyDamageBuff(mob, target, definition, ability)
			publishToTarget(target, "Result", actionId, actorEntityId(mob, definition), {
				targetEntityId = targetEntityId(target), skillId = ability.id, presentationKey = ability.presentationKey,
				outcome = "Applied", definitionId = definition.id,
			})
		elseif ability.kind == "SelfDamageBuff" then
			setMobDamageBuff(mob, ability.damageMultiplier or 1, ability.durationSeconds or 0)
			publishToTarget(target, "Result", actionId, actorEntityId(mob, definition), {
				targetEntityId = targetEntityId(target), skillId = ability.id, presentationKey = ability.presentationKey,
				outcome = "Applied", definitionId = definition.id,
			})
		end

		if mob.Parent ~= nil and mob:GetAttribute(CombatConfig.MobActionGenerationAttribute) == generation then
			mob:SetAttribute(CombatConfig.MobActionStateAttribute, "Recovery")
			mob:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, nil)
		end
	end)

	task.delay(math.max(0.8, ability.windupSeconds + 0.45), function()
		if mob.Parent ~= nil and mob:GetAttribute(CombatConfig.MobActionGenerationAttribute) == generation then
			mob:SetAttribute(CombatConfig.MobActionStateAttribute, nil)
			mob:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, nil)
		end
	end)
	return true
end

local function basicAttack(mob: Model, target: Player, definition: CombatTypes.MobDefinition): boolean
	local now = workspace:GetServerTimeNow()
	if now < (nextActionReadyAtByMob[mob] or 0) or now < (basicReadyAtByMob[mob] or 0) then return false end
	local humanoid, root = livingMobParts(mob)
	local targetRoot = livingPlayerRoot(target)
	if humanoid == nil or root == nil or targetRoot == nil then return false end
	if (targetRoot.Position - root.Position).Magnitude > definition.basicAttackRange + CombatConfig.RangeTolerance then return false end

	basicReadyAtByMob[mob] = now + definition.attackIntervalSeconds
	nextActionReadyAtByMob[mob] = now + definition.attackIntervalSeconds
	local actionId = HttpService:GenerateGUID(false)
	local previousGeneration = mob:GetAttribute(CombatConfig.MobActionGenerationAttribute)
	local generation = if typeof(previousGeneration) == "number" then previousGeneration + 1 else 1
	mob:SetAttribute(CombatConfig.MobActionGenerationAttribute, generation)
	mob:SetAttribute(CombatConfig.MobActionStateAttribute, "Windup")
	mob:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, true)

	task.delay(definition.attackWindupSeconds, function()
		if mob.Parent == nil or target.Parent ~= Players then return end
		if mob:GetAttribute(CombatConfig.MobActionGenerationAttribute) ~= generation then return end
		local _, currentRoot = livingMobParts(mob)
		local currentTargetRoot = livingPlayerRoot(target)
		if currentRoot == nil or currentTargetRoot == nil then return end
		if (currentTargetRoot.Position - currentRoot.Position).Magnitude > definition.basicAttackRange + CombatConfig.RangeTolerance then return end
		applyDamage(
			mob, target, definition, definition.basicAttackDamageType, definition.basicAttackDamage,
			actionId, "mob_basic_attack", definition.id
		)
		if mob.Parent ~= nil and mob:GetAttribute(CombatConfig.MobActionGenerationAttribute) == generation then
			mob:SetAttribute(CombatConfig.MobActionStateAttribute, "Recovery")
			mob:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, nil)
		end
	end)

	task.delay(definition.attackIntervalSeconds, function()
		if mob.Parent ~= nil and mob:GetAttribute(CombatConfig.MobActionGenerationAttribute) == generation then
			mob:SetAttribute(CombatConfig.MobActionStateAttribute, nil)
			mob:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, nil)
		end
	end)
	return true
end

function MobAbilityService.requestAttack(
	mob: Model,
	target: Player,
	definition: CombatTypes.MobDefinition
): boolean
	if not started or target.Parent ~= Players then return false end
	if mob:GetAttribute(CombatConfig.MobStunnedAttribute) == true then return false end
	if mob:GetAttribute(CombatConfig.MobActionStateAttribute) == "Windup" then return false end
	local _, root = livingMobParts(mob)
	local targetRoot = livingPlayerRoot(target)
	if root == nil or targetRoot == nil then return false end
	local distance = (targetRoot.Position - root.Position).Magnitude
	local now = workspace:GetServerTimeNow()
	local ability = selectAbility(mob, definition, distance, now)
	if ability ~= nil and beginAction(mob, definition, target, ability) then return true end
	return basicAttack(mob, target, definition)
end

function MobAbilityService.start(): ()
	started = true
end

function MobAbilityService.stop(): ()
	started = false
	for player in poisonGenerationByPlayer do
		poisonGenerationByPlayer[player] = (poisonGenerationByPlayer[player] or 0) + 1
	end
	table.clear(poisonGenerationByPlayer)
	table.clear(abilityCooldownsByMob)
	table.clear(basicReadyAtByMob)
	table.clear(nextActionReadyAtByMob)
	table.clear(abilityCursorByMob)
	table.clear(buffGenerationByMob)
end

return MobAbilityService
