--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionRules = require(ReplicatedStorage.Shared.combat.ActionRules)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatRules = require(ReplicatedStorage.Shared.combat.CombatRules)
local MobService = require(script.Parent.MobService)

local CombatService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local targetRequest = remotes:WaitForChild("TargetRequest") :: RemoteEvent
local attackRequest = remotes:WaitForChild("AttackRequest") :: RemoteEvent

type PlayerCombatState = {
	readyAt: number,
	actionState: "Ready" | "Windup" | "Recovery",
	bufferedTargetId: string?,
	generation: number,
}

local targetsByPlayer: { [Player]: string } = {}
local statesByPlayer: { [Player]: PlayerCombatState } = {}
local characterDeathConnections: { [Player]: RBXScriptConnection } = {}
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
local targetDeathConnections: { [Player]: RBXScriptConnection } = {}
local lastAttackRequestAtByPlayer: { [Player]: number } = {}
local started = false

local TARGET_ATTRIBUTE = CombatConfig.SelectedTargetAttribute
local ACTION_STATE_ATTRIBUTE = CombatConfig.BasicActionStateAttribute
local READY_AT_ATTRIBUTE = CombatConfig.BasicAttackReadyAtAttribute
local BUFFERED_ATTRIBUTE = CombatConfig.BasicAttackBufferedAttribute

local function replicateState(player: Player, state: PlayerCombatState): ()
	player:SetAttribute(ACTION_STATE_ATTRIBUTE, state.actionState)
	player:SetAttribute(READY_AT_ATTRIBUTE, state.readyAt)
	player:SetAttribute(BUFFERED_ATTRIBUTE, state.bufferedTargetId ~= nil)
end

local function getState(player: Player): PlayerCombatState
	local state = statesByPlayer[player]
	if state == nil then
		state = { readyAt = 0, actionState = "Ready", bufferedTargetId = nil, generation = 0 }
		statesByPlayer[player] = state
		replicateState(player, state)
	end
	return state
end

local function setReplicatedTarget(player: Player, entityId: string?): ()
	player:SetAttribute(TARGET_ATTRIBUTE, entityId)
end

local function getLivingCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then return nil end
	return root
end

local function getLivingMobRoot(mob: Model): BasePart?
	local humanoid = mob:FindFirstChildOfClass("Humanoid")
	local root = mob:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then return nil end
	return root
end

local function cancelPendingAction(player: Player): ()
	local state = getState(player)
	state.generation += 1
	state.actionState = "Ready"
	state.bufferedTargetId = nil
	state.readyAt = 0
	replicateState(player, state)
end

local function clearTarget(player: Player): ()
	local connection = targetDeathConnections[player]
	if connection ~= nil then connection:Disconnect() end
	targetDeathConnections[player] = nil
	targetsByPlayer[player] = nil
	getState(player).bufferedTargetId = nil
	replicateState(player, getState(player))
	setReplicatedTarget(player, nil)
end

local function clearPlayerState(player: Player): ()
	cancelPendingAction(player)
	clearTarget(player)
	statesByPlayer[player] = nil
	lastAttackRequestAtByPlayer[player] = nil
end

local function getValidAttackTarget(player: Player, expectedTargetId: string, expectedCharacter: Model?): Model?
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
		CombatConfig.BasicAttackRange + CombatConfig.RangeTolerance
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

	local acceptedAt = workspace:GetServerTimeNow()
	local acceptedCharacter = player.Character
	state.actionState = "Windup"
	state.readyAt = acceptedAt + CombatConfig.BasicAttackInterval
	state.bufferedTargetId = nil
	state.generation += 1
	replicateState(player, state)
	local generation = state.generation

	-- Resolve after the canonical wind-up; cooldown still starts at acceptance.
	task.delay(CombatConfig.BasicAttackWindupSeconds, function()
		local currentState = statesByPlayer[player]
		if currentState == nil or currentState ~= state or currentState.generation ~= generation then return end
		local target = getValidAttackTarget(player, expectedTargetId, acceptedCharacter)
		if target ~= nil then
			MobService.applyDamage(expectedTargetId, CombatConfig.BasicAttackDamage, player)
		end
		if statesByPlayer[player] == currentState and currentState.generation == generation then
			currentState.actionState = "Recovery"
			replicateState(player, currentState)
		end
	end)

	task.delay(CombatConfig.BasicAttackInterval, function()
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
	local target = MobService.getByEntityId(entityId)
	local targetRoot = if target ~= nil then getLivingMobRoot(target) else nil
	if playerRoot == nil or target == nil or targetRoot == nil then return end
	if not CombatRules.canSelectTarget(playerRoot.Position, targetRoot.Position, true, CombatConfig.TargetSelectionRange) then return end

	clearTarget(player)
	targetsByPlayer[player] = entityId
	setReplicatedTarget(player, entityId)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		targetDeathConnections[player] = humanoid.Died:Connect(function()
			if targetsByPlayer[player] == entityId then clearTarget(player) end
		end)
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
	targetRequest.OnServerEvent:Connect(onTargetRequest)
	attackRequest.OnServerEvent:Connect(onAttackRequest)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		clearPlayerState(player)
		local deathConnection = characterDeathConnections[player]
		if deathConnection ~= nil then deathConnection:Disconnect() end
		characterDeathConnections[player] = nil
		local addedConnection = characterAddedConnections[player]
		if addedConnection ~= nil then addedConnection:Disconnect() end
		characterAddedConnections[player] = nil
	end)
	for _, player in Players:GetPlayers() do onPlayerAdded(player) end
end

return CombatService
