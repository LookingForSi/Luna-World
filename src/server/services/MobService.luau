--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local EffectRules = require(ReplicatedStorage.Shared.combat.EffectRules)
local SkillRules = require(ReplicatedStorage.Shared.combat.SkillRules)

local MobService = {}

local SPAWN_CFRAME = CFrame.new(0, 3, -20)
local ROOT_SIZE = Vector3.new(4, 3, 6)
local WOLF_COLOR = Color3.fromRGB(110, 110, 120)

local definition = MobDefinitions.grey_wolf
local mobsByEntityId: { [string]: Model } = {}
local lastAttackerByEntityId: { [string]: Player } = {}
local mobDiedEvent = Instance.new("BindableEvent")
local started = false

MobService.MobDied = mobDiedEvent.Event

local function createWolf(): Model
	local entityId = HttpService:GenerateGUID(false)
	local model = Instance.new("Model")
	model.Name = definition.displayName
	model:SetAttribute("EntityId", entityId)
	model:SetAttribute("MobId", definition.id)
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
	model:PivotTo(SPAWN_CFRAME)
	model.Parent = workspace
	mobsByEntityId[entityId] = model

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
		if lastAttacker ~= nil and lastAttacker.Parent == Players then
			mobDiedEvent:Fire(lastAttacker, definition.id)
		end

		task.delay(definition.respawnSeconds, function()
			if model.Parent ~= nil then
				model:Destroy()
			end
			createWolf()
		end)
	end)

	return model
end

function MobService.start(): ()
	if started then
		return
	end
	started = true
	createWolf()
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

return MobService
