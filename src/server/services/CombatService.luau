--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatRules = require(ReplicatedStorage.Shared.combat.CombatRules)
local MobService = require(script.Parent.MobService)

local CombatService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local targetRequest = remotes:WaitForChild("TargetRequest") :: RemoteEvent
local attackRequest = remotes:WaitForChild("AttackRequest") :: RemoteEvent

local targetsByPlayer: { [Player]: string } = {}
local attackGeneration: { [Player]: number } = {}
local attackingByPlayer: { [Player]: boolean } = {}
local nextAttackAtByPlayer: { [Player]: number } = {}
local characterDeathConnections: { [Player]: RBXScriptConnection } = {}
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
local targetDeathConnections: { [Player]: RBXScriptConnection } = {}
local started = false

local TARGET_ATTRIBUTE = CombatConfig.SelectedTargetAttribute
local ATTACKING_ATTRIBUTE = CombatConfig.BasicAttackingAttribute

local function setReplicatedTarget(player: Player, entityId: string?): ()
	player:SetAttribute(TARGET_ATTRIBUTE, entityId)
end

local function setReplicatedAttacking(player: Player, active: boolean): ()
	player:SetAttribute(ATTACKING_ATTRIBUTE, active)
end

local function getLivingCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end

	return root
end

local function getLivingMobRoot(mob: Model): BasePart?
	local humanoid = mob:FindFirstChildOfClass("Humanoid")
	local root = mob:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end

	return root
end

local function cancelAttack(player: Player): ()
	attackGeneration[player] = (attackGeneration[player] or 0) + 1
	attackingByPlayer[player] = nil
	setReplicatedAttacking(player, false)
end

local function clearTarget(player: Player): ()
	local targetDeathConnection = targetDeathConnections[player]
	if targetDeathConnection ~= nil then
		targetDeathConnection:Disconnect()
		targetDeathConnections[player] = nil
	end
	targetsByPlayer[player] = nil
	setReplicatedTarget(player, nil)
end

local function clearPlayerState(player: Player): ()
	cancelAttack(player)
	clearTarget(player)
	nextAttackAtByPlayer[player] = nil
end

local function canAttackNow(player: Player, target: Model): boolean
	local playerRoot = getLivingCharacterRoot(player)
	local targetRoot = getLivingMobRoot(target)
	if playerRoot == nil or targetRoot == nil then
		return false
	end

	return CombatRules.canBasicAttack(
		playerRoot.Position,
		targetRoot.Position,
		true,
		CombatConfig.BasicAttackRange
	)
end

local function runAttackLoop(player: Player, generation: number): ()
	while player.Parent == Players and attackGeneration[player] == generation do
		local targetId = targetsByPlayer[player]
		if targetId == nil then
			break
		end

		local target = MobService.getByEntityId(targetId)
		if target == nil or getLivingMobRoot(target) == nil then
			clearTarget(player)
			break
		end

		local now = os.clock()
		local nextAttackAt = nextAttackAtByPlayer[player] or 0
		if now >= nextAttackAt and canAttackNow(player, target) then
			-- MobService owns damage and last-attacker attribution; the client never supplies either.
			local applied = MobService.applyDamage(targetId, CombatConfig.BasicAttackDamage, player)
			if not applied then
				clearTarget(player)
				break
			end
			nextAttackAtByPlayer[player] = now + CombatConfig.BasicAttackInterval
		end

		task.wait(CombatConfig.BasicAttackInterval)
	end

	if attackGeneration[player] == generation then
		attackingByPlayer[player] = nil
		setReplicatedAttacking(player, false)
	end
end

local function onTargetRequest(player: Player, entityId: unknown): ()
	if typeof(entityId) ~= "string" then
		return
	end

	local playerRoot = getLivingCharacterRoot(player)
	local target = MobService.getByEntityId(entityId)
	if playerRoot == nil or target == nil then
		return
	end

	local targetRoot = getLivingMobRoot(target)
	if targetRoot == nil then
		return
	end

	if not CombatRules.canSelectTarget(
		playerRoot.Position,
		targetRoot.Position,
		true,
		CombatConfig.TargetSelectionRange
	) then
		return
	end

	clearTarget(player)
	targetsByPlayer[player] = entityId
	setReplicatedTarget(player, entityId)

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		targetDeathConnections[player] = humanoid.Died:Connect(function()
			if targetsByPlayer[player] == entityId then
				cancelAttack(player)
				clearTarget(player)
			end
		end)
	end
end

local function onAttackRequest(player: Player, active: unknown): ()
	if typeof(active) ~= "boolean" then
		return
	end

	if not active then
		cancelAttack(player)
		return
	end

	-- Repeated true requests must not create parallel loops or reset attack cadence.
	if attackingByPlayer[player] then
		return
	end
	if player.Parent ~= Players or getLivingCharacterRoot(player) == nil or targetsByPlayer[player] == nil then
		return
	end

	local generation = (attackGeneration[player] or 0) + 1
	attackGeneration[player] = generation
	attackingByPlayer[player] = true
	setReplicatedAttacking(player, true)
	task.spawn(runAttackLoop, player, generation)
end

local function bindCharacter(player: Player, character: Model): ()
	clearPlayerState(player)

	local oldConnection = characterDeathConnections[player]
	if oldConnection ~= nil then
		oldConnection:Disconnect()
	end
	characterDeathConnections[player] = nil

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if player.Character == character and humanoid ~= nil and humanoid:IsA("Humanoid") then
		characterDeathConnections[player] = humanoid.Died:Connect(function()
			clearPlayerState(player)
		end)
	end
end

local function onPlayerAdded(player: Player): ()
	if characterAddedConnections[player] ~= nil then
		return
	end
	setReplicatedTarget(player, nil)
	setReplicatedAttacking(player, false)
	characterAddedConnections[player] = player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)
	if player.Character ~= nil then
		bindCharacter(player, player.Character)
	end
end

function CombatService.start(): ()
	if started then
		return
	end
	started = true

	targetRequest.OnServerEvent:Connect(onTargetRequest)
	attackRequest.OnServerEvent:Connect(onAttackRequest)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		clearPlayerState(player)
		attackGeneration[player] = nil

		local connection = characterDeathConnections[player]
		if connection ~= nil then
			connection:Disconnect()
			characterDeathConnections[player] = nil
		end

		local characterAddedConnection = characterAddedConnections[player]
		if characterAddedConnection ~= nil then
			characterAddedConnection:Disconnect()
			characterAddedConnections[player] = nil
		end
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CombatService
