--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local EffectRules = require(ReplicatedStorage.Shared.combat.EffectRules)
local SkillRules = require(ReplicatedStorage.Shared.combat.SkillRules)
local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local CombatPresentationService = require(script.Parent.CombatPresentationService)
local TerrainGrounding = require(script.Parent.Parent.world.TerrainGrounding)

local MobService = {}

local ROOT_SIZE = Vector3.new(4, 3, 6)
local SPAWN_Y = ROOT_SIZE.Y * 0.5
local WOLF_COLOR = Color3.fromRGB(110, 110, 120)

type SpawnSpec = {
	definitionKey: string,
	cframe: CFrame,
}

local function definitionKeyForId(mobId: string): string?
	for definitionKey, definition in MobDefinitions do
		if definition.id == mobId then
			return definitionKey
		end
	end
	return nil
end

local function configuredWorldSpawns(): { SpawnSpec }
	local result: { SpawnSpec } = {}
	for _, marker in WorldLayout.SpawnMarkers do
		if marker.spawnEnabled == false then
			continue
		end
		local definitionKey = definitionKeyForId(marker.mobId)
		-- World layout may already reserve markers for later milestones. Unknown
		-- definition ids remain visible as blockout placeholders but do not spawn
		-- authoritative combat entities yet.
		if definitionKey == nil then
			continue
		end

		local ground = TerrainGrounding.surfaceAt(marker.position)
		table.insert(result, {
			definitionKey = definitionKey,
			cframe = CFrame.new(ground + Vector3.new(0, SPAWN_Y, 0)),
		})
	end
	return result
end

local function removeKnownMobPlaceholders()
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("Purpose") == "MobPlaceholder" then
			local mobId = descendant:GetAttribute("MobId")
			if typeof(mobId) == "string" and definitionKeyForId(mobId) ~= nil then
				descendant:Destroy()
			end
		end
	end
end

local mobsByEntityId: { [string]: Model } = {}
local spawnedModels: { [Model]: boolean } = {}
local lastAttackerByEntityId: { [string]: Player } = {}
local mobDiedEvent = Instance.new("BindableEvent")
local mobSpawnedEvent = Instance.new("BindableEvent")
local hostileActionEvent = Instance.new("BindableEvent")
local started = false
local serviceGeneration = 0

MobService.MobDied = mobDiedEvent.Event
MobService.MobSpawned = mobSpawnedEvent.Event
MobService.HostileAction = hostileActionEvent.Event

local function createMob(definitionKey: string, spawnCFrame: CFrame, isRespawn: boolean?): Model
	local definition = MobDefinitions[definitionKey]
	assert(definition ~= nil, "unknown mob definition: " .. definitionKey)
	local entityId = HttpService:GenerateGUID(false)
	local model = Instance.new("Model")
	model.Name = definition.displayName
	model:SetAttribute("EntityId", entityId)
	model:SetAttribute("MobId", definition.id)
	model:SetAttribute("Level", definition.level)
	model:SetAttribute(CombatConfig.MobHomePositionAttribute, spawnCFrame.Position)
	model:SetAttribute(CombatConfig.MobMovementSpeedAttribute, definition.chaseSpeed)

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = ROOT_SIZE
	rootPart.Color = WOLF_COLOR
	rootPart.Material = Enum.Material.Slate
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = definition.maxHealth
	humanoid.Health = definition.maxHealth
	humanoid.WalkSpeed = definition.chaseSpeed
	humanoid.Parent = model

	model.PrimaryPart = rootPart
	model:PivotTo(spawnCFrame)
	model.Parent = workspace
	mobsByEntityId[entityId] = model
	spawnedModels[model] = true
	mobSpawnedEvent:Fire(model, definition, spawnCFrame, isRespawn == true)
	if isRespawn == true then
		CombatPresentationService.publish(CombatPresentationRules.create("Respawn", HttpService:GenerateGUID(false), "mob:" .. entityId, workspace:GetServerTimeNow(), {
			outcome = "Respawned",
			definitionId = definition.id,
		}))
	end

	local deathHandled = false
	humanoid.Died:Connect(function()
		if deathHandled then
			return
		end
		deathHandled = true

		if mobsByEntityId[entityId] == model then
			mobsByEntityId[entityId] = nil
		end

		local lastAttacker = lastAttackerByEntityId[entityId]
		lastAttackerByEntityId[entityId] = nil
		CombatPresentationService.publish(CombatPresentationRules.create("Death", HttpService:GenerateGUID(false), "mob:" .. entityId, workspace:GetServerTimeNow(), {
			outcome = "Dead",
			definitionId = definition.id,
		}))
		if lastAttacker ~= nil and lastAttacker.Parent == Players then
			mobDiedEvent:Fire(lastAttacker, definition.id, entityId)
		else
			mobDiedEvent:Fire(nil, definition.id, entityId)
		end

		local expectedGeneration = serviceGeneration
		task.delay(definition.respawnSeconds, function()
			spawnedModels[model] = nil
			if model.Parent ~= nil then
				model:Destroy()
			end
			if not started or serviceGeneration ~= expectedGeneration then
				return
			end
			createMob(definitionKey, spawnCFrame, true)
		end)
	end)

	return model
end

function MobService.start(): ()
	if started then
		return
	end
	started = true
	serviceGeneration += 1
	removeKnownMobPlaceholders()
	for _, spawn in configuredWorldSpawns() do
		createMob(spawn.definitionKey, spawn.cframe)
	end
end

function MobService.getAll(): { [string]: Model }
	return table.clone(mobsByEntityId)
end

function MobService.getDefinition(model: Model): CombatTypes.MobDefinition?
	local mobId = model:GetAttribute("MobId")
	if typeof(mobId) ~= "string" then return nil end
	for _, candidate in MobDefinitions do
		if candidate.id == mobId then return candidate end
	end
	return nil
end

function MobService.getByEntityId(entityId: string): Model?
	return mobsByEntityId[entityId]
end

function MobService.selectLivingTargetsInRadius(
	candidateModels: { [string]: Model },
	center: Vector3,
	radius: number,
	maximumTargets: number
): { { entityId: string, model: Model } }
	assert(radius >= 0, "radius must be nonnegative")
	assert(maximumTargets >= 1 and maximumTargets % 1 == 0, "maximumTargets must be a positive integer")
	local candidates: { { entityId: string, model: Model, distance: number } } = {}
	for entityId, model in candidateModels do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if humanoid ~= nil and humanoid.Health > 0 and root ~= nil and root:IsA("BasePart") then
			local distance = (root.Position - center).Magnitude
			if distance <= radius then
				table.insert(candidates, { entityId = entityId, model = model, distance = distance })
			end
		end
	end
	local selectionCandidates: { SkillRules.AreaCandidate } = {}
	local modelsBySelectedId: { [string]: Model } = {}
	for _, candidate in candidates do
		table.insert(selectionCandidates, { entityId = candidate.entityId, distance = candidate.distance })
		modelsBySelectedId[candidate.entityId] = candidate.model
	end
	local selectedIds = SkillRules.selectAreaTargets(selectionCandidates, radius, maximumTargets)
	local targets: { { entityId: string, model: Model } } = {}
	for _, entityId in selectedIds do
		table.insert(targets, { entityId = entityId, model = modelsBySelectedId[entityId] :: Model })
	end
	return targets
end

function MobService.getLivingTargetsInRadius(center: Vector3, radius: number, maximumTargets: number): { { entityId: string, model: Model } }
	return MobService.selectLivingTargetsInRadius(mobsByEntityId, center, radius, maximumTargets)
end

function MobService.registerHostileAction(entityId: string, attacker: Player): boolean
	local model = mobsByEntityId[entityId]
	if model == nil or attacker.Parent ~= Players then return false end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then return false end
	hostileActionEvent:Fire(model, attacker)
	return true
end

function MobService.applyDamage(entityId: string, amount: number, attacker: Player): boolean
	assert(amount >= 0, "damage must not be negative")

	local model = mobsByEntityId[entityId]
	if model == nil or attacker.Parent ~= Players then
		return false
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end

	-- Damage values and attribution are accepted only through this server-owned API.
	-- The attacker is intentionally retained in server memory, never replicated.
	lastAttackerByEntityId[entityId] = attacker
	MobService.registerHostileAction(entityId, attacker)
	humanoid:TakeDamage(amount)
	return true
end

function MobService.applyCalculatedMovement(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local baseMovementSpeed = model:GetAttribute(CombatConfig.MobMovementSpeedAttribute)
	if humanoid == nil or typeof(baseMovementSpeed) ~= "number" then return false end
	humanoid.WalkSpeed = EffectRules.resolveMovementSpeed(
		baseMovementSpeed,
		model:GetAttribute(CombatConfig.MobStunnedAttribute) == true,
		if typeof(model:GetAttribute(CombatConfig.MobMovementSlowAttribute)) == "number"
			then model:GetAttribute(CombatConfig.MobMovementSlowAttribute) :: number
			else nil
	)
	return true
end

function MobService.setMovementSpeed(entityId: string, movementSpeed: number): boolean
	assert(movementSpeed == movementSpeed and movementSpeed >= 0 and movementSpeed < math.huge, "movementSpeed must be finite and nonnegative")
	local model = mobsByEntityId[entityId]
	if model == nil then return false end
	model:SetAttribute(CombatConfig.MobMovementSpeedAttribute, movementSpeed)
	return MobService.applyCalculatedMovement(model)
end

function MobService.stop(): ()
	if not started then return end
	started = false
	serviceGeneration += 1

	local models = {}
	for model in spawnedModels do
		table.insert(models, model)
	end
	for _, model in models do
		if model.Parent ~= nil then model:Destroy() end
	end

	table.clear(spawnedModels)
	table.clear(mobsByEntityId)
	table.clear(lastAttackerByEntityId)
end

return MobService
