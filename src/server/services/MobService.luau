--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)

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

return MobService
