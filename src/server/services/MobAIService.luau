--!strict

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local MobAIRules = require(ReplicatedStorage.Shared.combat.MobAIRules)
local MobService = require(script.Parent.MobService)

type State = MobAIRules.State
type Record = {
	model: Model,
	definition: CombatTypes.MobDefinition,
	home: Vector3,
	state: State,
	target: Player?,
	hostileAttacker: Player?,
	generation: number,
	nextDecisionAt: number,
	decisionInFlight: boolean,
	connections: { RBXScriptConnection },
}
type AttackRequest = (Model, Player, CombatTypes.MobDefinition) -> boolean

local MobAIService = {}
local records: { [Model]: Record } = {}
local heartbeatConnection: RBXScriptConnection? = nil
local serviceConnections: { RBXScriptConnection } = {}
local attackRequest: AttackRequest? = nil
local started = false

local function livingRoot(player: Player): BasePart?
	if player.Parent ~= Players then return nil end
	local character = player.Character
	if character == nil then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then return nil end
	return root
end

local function mobParts(model: Model): (Humanoid?, BasePart?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	return humanoid, if root ~= nil and root:IsA("BasePart") then root else nil
end

local function nearestPlayer(origin: Vector3, radius: number): Player?
	local candidates: { MobAIRules.Candidate } = {}
	local byId: { [string]: Player } = {}
	for _, player in Players:GetPlayers() do
		local root = livingRoot(player)
		if root ~= nil then
			local id = tostring(player.UserId)
			table.insert(candidates, { id = id, distance = (root.Position - origin).Magnitude, eligible = true })
			byId[id] = player
		end
	end
	local selectedId = MobAIRules.nearestEligible(candidates, radius)
	return if selectedId ~= nil then byId[selectedId] else nil
end

local function setState(record: Record, state: State): ()
	local previousState = record.state
	record.state = state
	if MobAIRules.shouldInvalidateAction(previousState, state) then
		local actionGeneration = record.model:GetAttribute(CombatConfig.MobActionGenerationAttribute)
		record.model:SetAttribute(CombatConfig.MobActionGenerationAttribute, if typeof(actionGeneration) == "number" then actionGeneration + 1 else 1)
		record.model:SetAttribute(CombatConfig.MobActionStateAttribute, nil)
		record.model:SetAttribute(CombatConfig.MobActionInterruptibleAttribute, nil)
	end
	record.model:SetAttribute(CombatConfig.MobAIStateAttribute, state)
	record.model:SetAttribute(CombatConfig.MobAITargetAttribute, if record.target ~= nil then record.target.UserId else nil)
end

local function unregister(model: Model): ()
	local record = records[model]
	if record == nil then return end
	record.generation += 1
	setState(record, "Dead")
	for _, connection in record.connections do connection:Disconnect() end
	records[model] = nil
end

local function moveToward(record: Record, destination: Vector3, capturedGeneration: number): ()
	local humanoid, root = mobParts(record.model)
	if humanoid == nil or root == nil then return end
	local path = PathfindingService:CreatePath()
	local ok = pcall(function() path:ComputeAsync(root.Position, destination) end)
	if records[record.model] ~= record or not MobAIRules.isCurrentGeneration(capturedGeneration, record.generation) then return end
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local waypoint = waypoints[math.min(2, #waypoints)]
		if waypoint ~= nil then humanoid:MoveTo(waypoint.Position) return end
	end
	humanoid:MoveTo(destination)
end

local function decide(record: Record, now: number): ()
	local capturedGeneration = record.generation
	local humanoid, root = mobParts(record.model)
	if humanoid == nil or root == nil or humanoid.Health <= 0 or record.model.Parent == nil then
		setState(record, "Dead")
		return
	end
	local definition = record.definition
	local targetRoot = if record.target ~= nil then livingRoot(record.target) else nil
	if targetRoot == nil and record.state ~= "Idle" and record.state ~= "Return" then
		record.target = nearestPlayer(root.Position, definition.reacquireRadius)
		targetRoot = if record.target ~= nil then livingRoot(record.target) else nil
	end
	local detected = if record.state == "Idle" and definition.aggressionMode == "Aggressive"
		then nearestPlayer(root.Position, definition.detectionRadius)
		else nil
	local hostile = record.hostileAttacker
	record.hostileAttacker = nil
	if record.state == "Idle" then
		record.target = if hostile ~= nil and livingRoot(hostile) ~= nil then hostile else detected
		targetRoot = if record.target ~= nil then livingRoot(record.target) else nil
	end
	local distanceFromHome = (root.Position - record.home).Magnitude
	local targetDistance = if targetRoot ~= nil then (targetRoot.Position - root.Position).Magnitude else math.huge
	local nextState = MobAIRules.nextState(record.state, {
		alive = true,
		hasTarget = targetRoot ~= nil,
		detectedTarget = detected ~= nil,
		hostileAttacker = hostile ~= nil and record.target == hostile,
		beyondLeash = distanceFromHome > definition.leashDistance,
		inAttackRange = targetDistance <= definition.attackRange,
		atHome = distanceFromHome <= CombatConfig.MobHomeArrivalDistance,
	}, definition.aggressionMode)
	if nextState == "Return" and record.state ~= "Return" then record.target = nil end
	local previousState = record.state
	setState(record, nextState)
	if nextState == "Chase" and targetRoot ~= nil then
		moveToward(record, targetRoot.Position, capturedGeneration)
	elseif nextState == "Attack" and record.target ~= nil then
		humanoid:MoveTo(root.Position)
		if attackRequest ~= nil then attackRequest(record.model, record.target, definition) end
	elseif nextState == "Return" then
		moveToward(record, record.home, capturedGeneration)
	elseif nextState == "Idle" then
		humanoid:MoveTo(root.Position)
		if MobAIRules.shouldRestoreHealth(previousState, nextState, definition.restoreHealthOnReturn) then humanoid.Health = humanoid.MaxHealth end
	end
end

local function register(model: Model, definition: CombatTypes.MobDefinition, homeCFrame: CFrame): ()
	unregister(model)
	local record: Record = { model = model, definition = definition, home = homeCFrame.Position, state = "Idle", target = nil, hostileAttacker = nil, generation = 1, nextDecisionAt = 0, decisionInFlight = false, connections = {} }
	records[model] = record
	setState(record, "Idle")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then table.insert(record.connections, humanoid.Died:Connect(function() setState(record, "Dead"); unregister(model) end)) end
	table.insert(record.connections, model.AncestryChanged:Connect(function(_, parent) if parent == nil then unregister(model) end end))
end

function MobAIService.start(serverAttackRequest: AttackRequest): ()
	if started then return end
	started = true
	attackRequest = serverAttackRequest
	table.insert(serviceConnections, MobService.MobSpawned:Connect(register))
	table.insert(serviceConnections, MobService.HostileAction:Connect(function(model: Model, attacker: Player)
		local record = records[model]
		if record ~= nil and livingRoot(attacker) ~= nil and record.state ~= "Return" then record.hostileAttacker = attacker end
	end))
	for _, model in MobService.getAll() do
		local definition = MobService.getDefinition(model)
		local home = model:GetAttribute(CombatConfig.MobHomePositionAttribute)
		if definition ~= nil then register(model, definition, if typeof(home) == "Vector3" then CFrame.new(home) else model:GetPivot()) end
	end
	heartbeatConnection = RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, record in records do
			if MobAIRules.canBeginDecision(now, record.nextDecisionAt, record.decisionInFlight) then
				record.decisionInFlight = true
				record.nextDecisionAt = now + record.definition.decisionIntervalSeconds
				local generation = record.generation
				task.spawn(function()
					local ok, decisionError = pcall(decide, record, now)
					if not ok then warn(string.format("Mob AI decision failed for %s: %s", record.model.Name, tostring(decisionError))) end
					if records[record.model] == record and MobAIRules.isCurrentGeneration(generation, record.generation) then record.decisionInFlight = false end
				end)
			end
		end
	end)
end

function MobAIService.stop(): ()
	if heartbeatConnection ~= nil then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
	for _, connection in serviceConnections do connection:Disconnect() end
	table.clear(serviceConnections)
	local registeredModels = {}
	for model in records do table.insert(registeredModels, model) end
	for _, model in registeredModels do unregister(model) end
	attackRequest = nil
	started = false
end

return MobAIService
