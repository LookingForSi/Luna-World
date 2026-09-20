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
	navigationDetour: Vector3?,
	navigationGoal: Vector3?,
	navigationDetourUntil: number,
	patrolRadius: number,
	patrolCycleSeconds: number,
	nextPatrolAt: number,
	patrolIndex: number,
	spawnIndex: number,
	socialGroupId: string?,
	connections: { RBXScriptConnection },
}
type AttackRequest = (Model, Player, CombatTypes.MobDefinition) -> boolean

local MobAIService = {}
local records: { [Model]: Record } = {}
local heartbeatConnection: RBXScriptConnection? = nil
local serviceConnections: { RBXScriptConnection } = {}
local attackRequest: AttackRequest? = nil
local started = false

local OBSTACLE_PROBE_DISTANCE = 12
local DETOUR_CLEARANCE = 2.5
local DETOUR_REACHED_DISTANCE = 2.5
local DETOUR_LIFETIME_SECONDS = 3
local DETOUR_GOAL_RESET_DISTANCE = 5

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
	if state ~= "Chase" and state ~= "Return" then
		record.navigationDetour = nil
		record.navigationGoal = nil
		record.navigationDetourUntil = 0
	end
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

local function flatDistance(a: Vector3, b: Vector3): number
	local delta = Vector3.new(a.X - b.X, 0, a.Z - b.Z)
	return delta.Magnitude
end

local function obstacleHalfExtentAlong(part: BasePart, axis: Vector3): number
	return math.abs(axis:Dot(part.CFrame.RightVector)) * (part.Size.X * 0.5)
		+ math.abs(axis:Dot(part.CFrame.LookVector)) * (part.Size.Z * 0.5)
end

local function chooseObstacleDetour(record: Record, root: BasePart, destination: Vector3): Vector3?
	local flatDelta = Vector3.new(destination.X - root.Position.X, 0, destination.Z - root.Position.Z)
	local distance = flatDelta.Magnitude
	if distance <= 0.01 then return nil end
	local forward = flatDelta.Unit

	local filter: { Instance } = { record.model }
	if record.target ~= nil and record.target.Character ~= nil then table.insert(filter, record.target.Character) end
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = filter
	parameters.IgnoreWater = true

	-- Probe near the mob's feet. A simple placeholder Humanoid can physically fail
	-- on a low ledge that Roblox's navmesh considers walkable for a normal avatar.
	local footProbeHeight = math.max(0.25, math.min(0.75, root.Size.Y * 0.2))
	local origin = root.Position - Vector3.new(0, root.Size.Y * 0.5 - footProbeHeight, 0)
	local result = workspace:Raycast(origin, forward * math.min(distance, OBSTACLE_PROBE_DISTANCE), parameters)
	if result == nil or not result.Instance:IsA("BasePart") then return nil end
	-- Ground/slope contacts are not walls. We only detour around predominantly vertical faces.
	if math.abs(result.Normal.Y) >= 0.65 then return nil end

	local obstacle = result.Instance :: BasePart
	local side = Vector3.new(-forward.Z, 0, forward.X)
	local rootRadius = math.max(root.Size.X, root.Size.Z) * 0.5
	local clearance = obstacleHalfExtentAlong(obstacle, side) + rootRadius + DETOUR_CLEARANCE
	local center = Vector3.new(obstacle.Position.X, root.Position.Y, obstacle.Position.Z)
	local left = center + side * clearance
	local right = center - side * clearance

	local function routeCost(point: Vector3): number
		return flatDistance(root.Position, point) + flatDistance(point, destination)
	end
	return if routeCost(left) <= routeCost(right) then left else right
end

local function navigationDestination(record: Record, root: BasePart, destination: Vector3, now: number): Vector3
	if record.navigationGoal == nil or flatDistance(record.navigationGoal, destination) > DETOUR_GOAL_RESET_DISTANCE then
		record.navigationGoal = destination
		record.navigationDetour = nil
		record.navigationDetourUntil = 0
	else
		record.navigationGoal = destination
	end

	if record.navigationDetour ~= nil then
		if now < record.navigationDetourUntil and flatDistance(root.Position, record.navigationDetour) > DETOUR_REACHED_DISTANCE then
			return record.navigationDetour
		end
		record.navigationDetour = nil
		record.navigationDetourUntil = 0
	end

	local detour = chooseObstacleDetour(record, root, destination)
	if detour ~= nil then
		record.navigationDetour = detour
		record.navigationDetourUntil = now + DETOUR_LIFETIME_SECONDS
		return detour
	end
	return destination
end

local function patrolDestination(record: Record, currentY: number): Vector3
	local steps = 8
	local angle = ((record.patrolIndex - 1) % steps) / steps * math.pi * 2
	local distance = record.patrolRadius * (if record.patrolIndex % 2 == 0 then 0.65 else 1)
	local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local tangent = Vector3.new(-radial.Z, 0, radial.X)
	-- Linked groups share the same patrol phase so guards actually move as a
	-- patrol. SpawnIndex supplies a small formation offset to avoid stacking.
	local formationOffset = if record.socialGroupId ~= nil then (record.spawnIndex - 1) * 4 else 0
	return Vector3.new(record.home.X, currentY, record.home.Z)
		+ radial * distance
		+ tangent * formationOffset
end

local function moveToward(record: Record, destination: Vector3, capturedGeneration: number, now: number): ()
	local humanoid, root = mobParts(record.model)
	if humanoid == nil or root == nil then return end
	local moveDestination = navigationDestination(record, root, destination, now)
	local path = PathfindingService:CreatePath({
		AgentRadius = math.max(2, math.min(root.Size.X, root.Size.Z) * 0.5),
		AgentHeight = math.max(4, root.Size.Y + 1),
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 4,
	})
	local ok = pcall(function() path:ComputeAsync(root.Position, moveDestination) end)
	if records[record.model] ~= record or not MobAIRules.isCurrentGeneration(capturedGeneration, record.generation) then return end
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local waypoint = waypoints[math.min(2, #waypoints)]
		if waypoint ~= nil then
			humanoid:MoveTo(waypoint.Position)
			return
		end
	end
	-- A failed path may still occur on the sparse playground. The selected destination
	-- is already obstacle-aware, so the fallback does not simply walk into the same wall.
	humanoid:MoveTo(moveDestination)
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
		moveToward(record, targetRoot.Position, capturedGeneration, now)
	elseif nextState == "Attack" and record.target ~= nil then
		humanoid:MoveTo(root.Position)
		local accepted = if attackRequest ~= nil then attackRequest(record.model, record.target, definition) else false
		-- The maximum attack range may belong to a cooldown ability. If that action
		-- is unavailable, keep closing toward the basic attack instead of freezing
		-- forever at the outer ability radius.
		if not accepted and targetRoot ~= nil and targetDistance > definition.basicAttackRange then
			moveToward(record, targetRoot.Position, capturedGeneration, now)
		end
	elseif nextState == "Return" then
		moveToward(record, record.home, capturedGeneration, now)
	elseif nextState == "Idle" then
		if MobAIRules.shouldRestoreHealth(previousState, nextState, definition.restoreHealthOnReturn) then
			humanoid.Health = humanoid.MaxHealth
		end
		if record.patrolRadius > 0 and now >= record.nextPatrolAt then
			record.patrolIndex += 1
			record.nextPatrolAt = now + record.patrolCycleSeconds
			moveToward(record, patrolDestination(record, root.Position.Y), capturedGeneration, now)
		elseif previousState ~= "Idle" or record.patrolRadius <= 0 then
			humanoid:MoveTo(root.Position)
		end
	end
end

local function register(model: Model, definition: CombatTypes.MobDefinition, homeCFrame: CFrame): ()
	unregister(model)
	local record: Record = {
		model = model,
		definition = definition,
		home = homeCFrame.Position,
		state = "Idle",
		target = nil,
		hostileAttacker = nil,
		generation = 1,
		nextDecisionAt = 0,
		decisionInFlight = false,
		navigationDetour = nil,
		navigationGoal = nil,
		navigationDetourUntil = 0,
		patrolRadius = if typeof(model:GetAttribute("PatrolRadius")) == "number" then model:GetAttribute("PatrolRadius") :: number else 0,
		patrolCycleSeconds = if typeof(model:GetAttribute("PatrolCycleSeconds")) == "number" then model:GetAttribute("PatrolCycleSeconds") :: number else 10,
		nextPatrolAt = workspace:GetServerTimeNow() + 2,
		patrolIndex = if typeof(model:GetAttribute("SocialGroupId")) == "string"
			then 0
			else (if typeof(model:GetAttribute("SpawnIndex")) == "number" then model:GetAttribute("SpawnIndex") :: number else 0),
		spawnIndex = if typeof(model:GetAttribute("SpawnIndex")) == "number" then model:GetAttribute("SpawnIndex") :: number else 1,
		socialGroupId = if typeof(model:GetAttribute("SocialGroupId")) == "string" then model:GetAttribute("SocialGroupId") :: string else nil,
		connections = {},
	}
	records[model] = record
	setState(record, "Idle")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		table.insert(record.connections, humanoid.Died:Connect(function()
			setState(record, "Dead")
			unregister(model)
		end))
	end
	table.insert(record.connections, model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then unregister(model) end
	end))
end

function MobAIService.start(serverAttackRequest: AttackRequest): ()
	if started then return end
	started = true
	attackRequest = serverAttackRequest
	table.insert(serviceConnections, MobService.MobSpawned:Connect(register))
	table.insert(serviceConnections, MobService.HostileAction:Connect(function(model: Model, attacker: Player)
		local record = records[model]
		if record == nil or livingRoot(attacker) == nil then return end
		local socialGroupId = model:GetAttribute("SocialGroupId")
		local typedSocialGroupId = if typeof(socialGroupId) == "string" then socialGroupId else nil
		if record.state ~= "Return" then record.hostileAttacker = attacker end
		if not MobAIRules.canRequestSocialAssist(record.state, typedSocialGroupId) then return end
		local _, sourceRoot = mobParts(model)
		if sourceRoot == nil then return end
		for otherModel, otherRecord in records do
			if otherModel ~= model
				and otherModel:GetAttribute("SocialGroupId") == typedSocialGroupId
				and otherRecord.state ~= "Return"
			then
				local otherHumanoid, otherRoot = mobParts(otherModel)
				local assistRadius = otherRecord.definition.socialAssistRadius
				if otherHumanoid ~= nil and otherHumanoid.Health > 0 and otherRoot ~= nil
					and assistRadius > 0
					and (otherRoot.Position - sourceRoot.Position).Magnitude <= assistRadius
				then
					otherRecord.hostileAttacker = attacker
				end
			end
		end
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
