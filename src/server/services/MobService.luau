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

local VISUAL_PROFILES = table.freeze({
	WolfYoung = table.freeze({ size = Vector3.new(3.5, 2.5, 5), color = Color3.fromRGB(125, 125, 135) }),
	Wolf = table.freeze({ size = Vector3.new(4, 3, 6), color = Color3.fromRGB(105, 105, 120) }),
	WolfAlpha = table.freeze({ size = Vector3.new(5, 3.8, 7.2), color = Color3.fromRGB(82, 82, 98) }),
	DireWolf = table.freeze({ size = Vector3.new(4.8, 3.6, 7), color = Color3.fromRGB(72, 78, 88) }),
	DireWolfAlpha = table.freeze({ size = Vector3.new(5.6, 4.2, 8), color = Color3.fromRGB(58, 63, 75) }),
	Goblin = table.freeze({ size = Vector3.new(3, 5, 3), color = Color3.fromRGB(86, 122, 70) }),
	GoblinWarrior = table.freeze({ size = Vector3.new(3.5, 5.5, 3.5), color = Color3.fromRGB(74, 108, 58) }),
	GoblinShaman = table.freeze({ size = Vector3.new(3.2, 5.4, 3.2), color = Color3.fromRGB(82, 90, 132) }),
	GoblinChief = table.freeze({ size = Vector3.new(4.2, 6.5, 4.2), color = Color3.fromRGB(72, 88, 50) }),
	Spider = table.freeze({ size = Vector3.new(5.5, 2.2, 5.5), color = Color3.fromRGB(35, 31, 45) }),
	SpiderLarge = table.freeze({ size = Vector3.new(7.5, 3, 7.5), color = Color3.fromRGB(30, 25, 38) }),
	SpiderForest = table.freeze({ size = Vector3.new(5.8, 2.4, 5.8), color = Color3.fromRGB(42, 52, 38) }),
	Skeleton = table.freeze({ size = Vector3.new(2.6, 5.8, 2.6), color = Color3.fromRGB(180, 180, 164) }),
	SkeletonArcher = table.freeze({ size = Vector3.new(2.6, 5.8, 2.6), color = Color3.fromRGB(165, 170, 158) }),
	GraveGuardian = table.freeze({ size = Vector3.new(4.2, 7, 4.2), color = Color3.fromRGB(105, 110, 112) }),
	Acolyte = table.freeze({ size = Vector3.new(3, 6, 3), color = Color3.fromRGB(82, 70, 105) }),
	ShrineGuardian = table.freeze({ size = Vector3.new(4, 6.8, 4), color = Color3.fromRGB(94, 88, 110) }),
	Sentinel = table.freeze({ size = Vector3.new(4.8, 8, 4.8), color = Color3.fromRGB(120, 126, 132) }),
	Watcher = table.freeze({ size = Vector3.new(3.8, 7, 3.8), color = Color3.fromRGB(100, 112, 140) }),
	Warden = table.freeze({ size = Vector3.new(6.2, 10, 6.2), color = Color3.fromRGB(92, 104, 138) }),
})

type SpawnSpec = {
	definitionKey: string,
	cframe: CFrame,
	spawnMarkerId: string,
	spawnIndex: number,
	socialGroupId: string?,
	patrolRadius: number,
	patrolCycleSeconds: number,
}

local function definitionKeyForId(mobId: string): string?
	for definitionKey, definition in MobDefinitions do
		if definition.id == mobId then
			return definitionKey
		end
	end
	return nil
end

local function visualProfile(definition: CombatTypes.MobDefinition): { size: Vector3, color: Color3 }
	local profile = VISUAL_PROFILES[definition.visualProfile]
	assert(profile ~= nil, "unknown mob visual profile: " .. definition.visualProfile)
	return profile
end

local function spawnOffset(index: number, count: number, radius: number): Vector3
	if count <= 1 then return Vector3.zero end
	local fraction = math.sqrt((index - 0.5) / count)
	local angle = (index - 1) * 2.399963229728653
	local distance = math.min(radius * 0.58, radius * 0.18 + radius * 0.42 * fraction)
	return Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function configuredWorldSpawns(): { SpawnSpec }
	local result: { SpawnSpec } = {}
	for _, marker in WorldLayout.SpawnMarkers do
		if marker.spawnEnabled == false then
			continue
		end
		local definitionKey = definitionKeyForId(marker.mobId)
		if definitionKey == nil then
			continue
		end
		local definition = MobDefinitions[definitionKey]
		local profile = visualProfile(definition)
		local count = marker.count or 1
		for index = 1, count do
			local candidate = marker.position + spawnOffset(index, count, marker.radius)
			local ground = TerrainGrounding.surfaceAt(candidate)
			table.insert(result, {
				definitionKey = definitionKey,
				cframe = CFrame.new(ground + Vector3.new(0, profile.size.Y * 0.5 + 0.15, 0)),
				spawnMarkerId = marker.id,
				spawnIndex = index,
				socialGroupId = marker.socialGroupId,
				patrolRadius = marker.patrolRadius or 0,
				patrolCycleSeconds = marker.patrolCycleSeconds or 10,
			})
		end
	end
	return result
end

local function removeMobPlaceholders()
	-- Mob Content Pass v0.1 owns the complete open-world population. Any
	-- presentation-only mob silhouettes from the world blockout must disappear
	-- before authoritative entities are spawned, including obsolete reservation IDs.
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("Purpose") == "MobPlaceholder" then
			descendant:Destroy()
		end
	end
end

local mobsByEntityId: { [string]: Model } = {}
local spawnedModels: { [Model]: boolean } = {}
local configuredMarkerActive: { [string]: boolean } = {}
local lastAttackerByEntityId: { [string]: Player } = {}
local mobDiedEvent = Instance.new("BindableEvent")
local mobSpawnedEvent = Instance.new("BindableEvent")
local hostileActionEvent = Instance.new("BindableEvent")
local started = false
local serviceGeneration = 0

MobService.MobDied = mobDiedEvent.Event
MobService.MobSpawned = mobSpawnedEvent.Event
MobService.HostileAction = hostileActionEvent.Event

local MOB_NAMEPLATE_MAX_DISTANCE = 100
local GLOBAL_MOB_MOVEMENT_MULTIPLIER = 1.2
local WOLF_MOVEMENT_MULTIPLIER = 1.25

local function addMobPresentation(
	model: Model,
	rootPart: BasePart,
	definition: CombatTypes.MobDefinition,
	profile: { size: Vector3, color: Color3 }
): BillboardGui
	local hitbox = Instance.new("Part")
	hitbox.Name = "TargetHitbox"
	hitbox.Size = Vector3.new(
		math.max(7, profile.size.X + 4),
		math.max(5, profile.size.Y + 3),
		math.max(7, profile.size.Z + 3)
	)
	-- Keep the larger click proxy centered on the visible primitive. Moving the
	-- proxy upward made the selectable area drift away from short silhouettes.
	hitbox.CFrame = rootPart.CFrame
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Massless = true
	hitbox.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Name = "TargetHitboxWeld"
	weld.Part0 = rootPart
	weld.Part1 = hitbox
	weld.Parent = hitbox

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MobNameplate"
	billboard.Adornee = rootPart
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = MOB_NAMEPLATE_MAX_DISTANCE
	billboard.Size = UDim2.fromOffset(220, 30)
	billboard.StudsOffset = Vector3.new(0, profile.size.Y * 0.65 + 2.2, 0)
	billboard.Parent = rootPart

	local text = Instance.new("TextLabel")
	text.Name = "Name"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.Text = string.format("LV %d · %s", definition.level, definition.displayName)
	text.TextColor3 = Color3.fromRGB(240, 240, 236)
	text.TextStrokeColor3 = Color3.fromRGB(18, 20, 24)
	text.TextStrokeTransparency = 0.25
	text.TextSize = 14
	text.TextWrapped = false
	text.Parent = billboard

	return billboard
end

local function createMob(spawn: SpawnSpec, isRespawn: boolean?): Model
	local definition = MobDefinitions[spawn.definitionKey]
	assert(definition ~= nil, "unknown mob definition: " .. spawn.definitionKey)
	local spawnCFrame = spawn.cframe
	local profile = visualProfile(definition)
	local entityId = HttpService:GenerateGUID(false)
	local model = Instance.new("Model")
	model.Name = definition.displayName
	model:SetAttribute("EntityId", entityId)
	model:SetAttribute("MobId", definition.id)
	model:SetAttribute("Level", definition.level)
	model:SetAttribute("PhysicalDefense", definition.physicalDefense)
	model:SetAttribute("MagicDefense", definition.magicDefense)
	model:SetAttribute("Faction", definition.faction)
	model:SetAttribute("SpawnMarkerId", spawn.spawnMarkerId)
	model:SetAttribute("SpawnIndex", spawn.spawnIndex)
	model:SetAttribute("SocialGroupId", spawn.socialGroupId)
	model:SetAttribute("SocialAssistRadius", definition.socialAssistRadius)
	model:SetAttribute("PatrolRadius", spawn.patrolRadius)
	model:SetAttribute("PatrolCycleSeconds", spawn.patrolCycleSeconds)
	model:SetAttribute(CombatConfig.MobHomePositionAttribute, spawnCFrame.Position)
	local factionMovementMultiplier = if definition.faction == "wolf" then WOLF_MOVEMENT_MULTIPLIER else 1
	local movementSpeed = definition.chaseSpeed * GLOBAL_MOB_MOVEMENT_MULTIPLIER * factionMovementMultiplier
	model:SetAttribute(CombatConfig.MobMovementSpeedAttribute, movementSpeed)
	model:SetAttribute(CombatConfig.MobOutgoingDamageMultiplierAttribute, 1)

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = profile.size
	rootPart.Color = profile.color
	rootPart.Material = Enum.Material.Slate
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.Parent = model

	local nameplate = addMobPresentation(model, rootPart, definition, profile)

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = definition.maxHealth
	humanoid.Health = definition.maxHealth
	humanoid.WalkSpeed = movementSpeed
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
		nameplate.Enabled = false

		if mobsByEntityId[entityId] == model then
			mobsByEntityId[entityId] = nil
		end

		local lastAttacker = lastAttackerByEntityId[entityId]
		lastAttackerByEntityId[entityId] = nil
		local deathPosition = model:GetPivot().Position
		CombatPresentationService.publish(CombatPresentationRules.create("Death", HttpService:GenerateGUID(false), "mob:" .. entityId, workspace:GetServerTimeNow(), {
			outcome = "Dead",
			definitionId = definition.id,
		}))
		if lastAttacker ~= nil and lastAttacker.Parent == Players then
			mobDiedEvent:Fire(lastAttacker, definition.id, entityId, deathPosition)
		else
			mobDiedEvent:Fire(nil, definition.id, entityId, deathPosition)
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
			if configuredMarkerActive[spawn.spawnMarkerId] == false then
				return
			end
			createMob(spawn, true)
		end)
	end)

	return model
end

-- Dungeon content uses the same authoritative entity/combat pipeline without
-- adding its instanced spawn markers to the open-world WorldLayout contract.
function MobService.spawnConfigured(definitionKey: string, position: Vector3, spawnMarkerId: string, spawnIndex: number): Model?
	if not started or MobDefinitions[definitionKey] == nil then return nil end
	configuredMarkerActive[spawnMarkerId] = true
	return createMob({ definitionKey=definitionKey, cframe=CFrame.new(position), spawnMarkerId=spawnMarkerId, spawnIndex=spawnIndex, socialGroupId=spawnMarkerId, patrolRadius=8, patrolCycleSeconds=10 })
end

function MobService.removeConfigured(spawnMarkerId: string): ()
	configuredMarkerActive[spawnMarkerId] = false
	for model in spawnedModels do
		if model:GetAttribute("SpawnMarkerId") == spawnMarkerId then
			local entityId = model:GetAttribute("EntityId")
			if typeof(entityId) == "string" then mobsByEntityId[entityId] = nil; lastAttackerByEntityId[entityId] = nil end
			spawnedModels[model] = nil
			model:Destroy()
		end
	end
end

function MobService.start(): ()
	if started then
		return
	end
	started = true
	serviceGeneration += 1
	removeMobPlaceholders()
	for _, spawn in configuredWorldSpawns() do
		createMob(spawn)
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

function MobService.applyDamage(
	entityId: string,
	amount: number,
	attacker: Player,
	damageType: CombatTypes.MobDamageType?
): (boolean, number?)
	assert(amount >= 0, "damage must not be negative")

	local model = mobsByEntityId[entityId]
	if model == nil or attacker.Parent ~= Players then
		return false, nil
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return false, nil
	end

	local definition = MobService.getDefinition(model)
	if definition == nil then return false, nil end
	local resolvedDamageType = damageType
	if resolvedDamageType == nil then
		resolvedDamageType = if attacker:GetAttribute(CombatConfig.ArchetypeAttribute) == "mystic" then "Magic" else "Physical"
	end
	local defense = if resolvedDamageType == "Magic" then definition.magicDefense else definition.physicalDefense
	local appliedAmount = math.max(1, math.floor(amount - defense + 0.5))

	lastAttackerByEntityId[entityId] = attacker
	MobService.registerHostileAction(entityId, attacker)
	humanoid:TakeDamage(appliedAmount)
	return true, appliedAmount
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
	table.clear(configuredMarkerActive)
	table.clear(mobsByEntityId)
	table.clear(lastAttackerByEntityId)
end

return MobService
