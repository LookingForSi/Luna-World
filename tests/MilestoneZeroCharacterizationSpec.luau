--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatRules = require(ReplicatedStorage.Shared.combat.CombatRules)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)
local CombatEffectService = require(ServerScriptService.Server.services.CombatEffectService)
local MobService = require(ServerScriptService.Server.services.MobService)
local attackContractReady = ReplicatedStorage
	:WaitForChild("TestRemotes")
	:WaitForChild("MilestoneZeroAttackContractReady") :: RemoteFunction
local attackContractComplete = ReplicatedStorage
	:WaitForChild("TestRemotes")
	:WaitForChild("MilestoneZeroAttackContractComplete") :: RemoteEvent
local lifecycleStart = ReplicatedStorage.TestRemotes:WaitForChild("ManualAttackLifecycleStart") :: RemoteEvent
local lifecycleCommand = ReplicatedStorage.TestRemotes:WaitForChild("ManualAttackLifecycleCommand") :: RemoteFunction
local lifecycleComplete = ReplicatedStorage.TestRemotes:WaitForChild("ManualAttackLifecycleComplete") :: RemoteEvent
local skillRuntimeStart = ReplicatedStorage.TestRemotes:WaitForChild("SkillRuntimeStart") :: RemoteEvent
local skillRuntimeCommand = ReplicatedStorage.TestRemotes:WaitForChild("SkillRuntimeCommand") :: RemoteFunction
local skillRuntimeComplete = ReplicatedStorage.TestRemotes:WaitForChild("SkillRuntimeComplete") :: RemoteEvent

local function waitUntil<T>(description: string, timeoutSeconds: number, readValue: () -> T?): T
	local deadline = os.clock() + timeoutSeconds
	local value = readValue()
	while value == nil and os.clock() < deadline do
		task.wait()
		value = readValue()
	end
	assert(value ~= nil, string.format("timed out waiting for %s", description))
	return value
end

local function findPlayer(): Player?
	return Players:GetPlayers()[1]
end

local function findMilestoneZeroMob(): { model: Model, entityId: string }?
	for _, child in workspace:GetChildren() do
		local entityId = child:GetAttribute("EntityId")
		local humanoid = child:FindFirstChildOfClass("Humanoid")
		if child:IsA("Model")
			and child:GetAttribute("MobId") == MobDefinitions.grey_wolf.id
			and typeof(entityId) == "string"
			and humanoid ~= nil
			and humanoid.Health > 0
		then
			return { model = child, entityId = entityId }
		end
	end
	return nil
end

local function waitForBootstrap(): (Player, Model, string)
	MobService.start()
	local player = waitUntil("a test player", 10, findPlayer)
	waitUntil("initialized SessionXP", 10, function(): boolean?
		return if typeof(player:GetAttribute("SessionXP")) == "number" then true else nil
	end)
	local mobFixture = waitUntil("the milestone zero grey wolf", 10, findMilestoneZeroMob)

	-- The accepted bootstrap connects the reward handler synchronously after starting services.
	-- Two server heartbeats form the readiness boundary after both observable fixtures exist.
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	return player, mobFixture.model, mobFixture.entityId
end

return function(TestRunner)
	TestRunner.run("flame burst server seam selects nearest living targets and applies each once", function()
		local function makeCandidate(entityId: string, distance: number, alive: boolean): Model
			local model = Instance.new("Model")
			model.Name = entityId
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = Vector3.new(distance, 0, 0)
			root.Parent = model
			local humanoid = Instance.new("Humanoid")
			humanoid.MaxHealth = 100
			humanoid.Health = if alive then 100 else 0
			humanoid.Parent = model
			return model
		end

		local candidates: { [string]: Model } = {
			center = makeCandidate("center", 0, true),
			near_1 = makeCandidate("near_1", 1, true),
			near_2 = makeCandidate("near_2", 2, true),
			near_3 = makeCandidate("near_3", 3, true),
			n_plus_one = makeCandidate("n_plus_one", 4, true),
			outside = makeCandidate("outside", 11, true),
			dead = makeCandidate("dead", 0.5, false),
		}
		local config = CombatConfig.ArchetypeStats.mystic
		local stats: CombatTypes.CombatStatSnapshot = {
			resource = { resourceType = "Mana", current = config.maximumResource, maximum = config.maximumResource },
			resourceRegenerationPerSecond = config.resourceRegenerationPerSecond,
			physicalAttack = config.physicalAttack,
			magicAttack = config.magicAttack,
			basePhysicalDefense = config.physicalDefense,
			physicalDefense = config.physicalDefense,
			baseAttackSpeedMultiplier = config.attackSpeedMultiplier,
			attackSpeedMultiplier = config.attackSpeedMultiplier,
			criticalChance = 0,
			baseMovementSpeed = config.movementSpeed,
			movementSpeed = config.movementSpeed,
		}
		local applied: { [string]: number } = {}
		local actor = waitUntil("an area damage test player", 10, findPlayer)
		local result = CombatEffectService.executeAreaDamage(
			actor,
			stats,
			SkillDefinitions.flame_burst,
			candidates.center,
			function(center: Vector3, radius: number, maximumTargets: number)
				return MobService.selectLivingTargetsInRadius(candidates, center, radius, maximumTargets)
			end,
			function(entityId: string, _amount: number, attacker: Player): boolean
				assert(attacker == actor)
				applied[entityId] = (applied[entityId] or 0) + 1
				return true
			end,
			function(): number return 0.5 end
		)
		assert(result.applied)
		assert(applied.center == 1 and applied.near_1 == 1 and applied.near_2 == 1 and applied.near_3 == 1)
		assert(applied.n_plus_one == nil and applied.outside == nil and applied.dead == nil)
		for _, model in candidates do model:Destroy() end
	end)

	TestRunner.run("milestone zero target selection requires a living target in range", function()
		local origin = Vector3.zero
		local boundary = Vector3.new(CombatConfig.TargetSelectionRange, 0, 0)
		local outside = boundary + Vector3.new(0.01, 0, 0)

		assert(CombatRules.canSelectTarget(origin, boundary, true, CombatConfig.TargetSelectionRange))
		assert(not CombatRules.canSelectTarget(origin, outside, true, CombatConfig.TargetSelectionRange))
		assert(not CombatRules.canSelectTarget(origin, boundary, false, CombatConfig.TargetSelectionRange))
	end)

	TestRunner.run("milestone zero basic attack requires a living target in range", function()
		local origin = Vector3.zero
		local boundary = Vector3.new(CombatConfig.BasicAttackRange, 0, 0)
		local outside = boundary + Vector3.new(0.01, 0, 0)

		assert(CombatRules.canBasicAttack(origin, boundary, true, CombatConfig.BasicAttackRange))
		assert(not CombatRules.canBasicAttack(origin, outside, true, CombatConfig.BasicAttackRange))
		assert(not CombatRules.canBasicAttack(origin, boundary, false, CombatConfig.BasicAttackRange))
	end)

	TestRunner.run("manual attack migration preserves one-time mob death and XP reward", function()
		local completedByPlayer: { [Player]: boolean } = {}
		local lifecycleCompletedByPlayer: { [Player]: boolean } = {}
		local skillRuntimeCompletedByPlayer: { [Player]: boolean } = {}
		local fixtureReady = false
		local completionConnection: RBXScriptConnection? = attackContractComplete.OnServerEvent:Connect(function(sender)
			completedByPlayer[sender] = true
		end)
		local lifecycleCompletionConnection = lifecycleComplete.OnServerEvent:Connect(function(sender)
			lifecycleCompletedByPlayer[sender] = true
		end)
		local skillRuntimeCompletionConnection = skillRuntimeComplete.OnServerEvent:Connect(function(sender)
			skillRuntimeCompletedByPlayer[sender] = true
		end)
		attackContractReady.OnServerInvoke = function(_sender: Player): boolean
			waitUntil("positioned server attack fixture", 12, function(): boolean?
				return if fixtureReady then true else nil
			end)
			return true
		end
		local deathConnection: RBXScriptConnection? = nil
		local mobToCleanUp: Model? = nil
		local mobRootToRestore: BasePart? = nil
		local originalMobPivot: CFrame? = nil
		local originalMobRootAnchored: boolean? = nil
		local lifecycleMob: Model? = nil
		local originalRespawnTime = Players.RespawnTime

		local function prepareLifecycleTarget(player: Player): string
			local fixture = waitUntil("a respawned lifecycle wolf", 10, findMilestoneZeroMob)
			lifecycleMob = fixture.model
			local root = fixture.model:FindFirstChild("HumanoidRootPart")
			local playerRoot = waitUntil("living player root for lifecycle", 10, function(): BasePart?
				local character = player.Character
				local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
				local candidate = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
				return if humanoid ~= nil and humanoid.Health > 0 and candidate ~= nil and candidate:IsA("BasePart") then candidate else nil
			end)
			assert(root ~= nil and root:IsA("BasePart"))
			root.Anchored = true
			fixture.model:PivotTo(playerRoot.CFrame * CFrame.new(0, 0, -(CombatConfig.BasicAttackRange * 0.5)))
			return fixture.entityId
		end

		local ok, failure = pcall(function()
			local player, mob, entityId = waitForBootstrap()
			mobToCleanUp = mob
			local humanoid = mob:FindFirstChildOfClass("Humanoid")
			assert(humanoid ~= nil, "milestone zero grey wolf must have a Humanoid")
			local mobRoot = mob:FindFirstChild("HumanoidRootPart")
			assert(mobRoot ~= nil and mobRoot:IsA("BasePart"), "milestone zero grey wolf must have a root")
			local playerRoot = waitUntil("a living player root", 10, function(): BasePart?
				local character = player.Character
				local playerHumanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
				local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
				if playerHumanoid ~= nil and playerHumanoid.Health > 0 and root ~= nil and root:IsA("BasePart") then
					return root
				end
				return nil
			end)

			-- Exercise the real server effect service without stretching gameplay tuning
			-- merely to make a refresh fit inside the production skill cooldown.
			local rangerTuning = CombatConfig.ArchetypeStats.ranger
			local effectStats: CombatTypes.CombatStatSnapshot = {
				resource = { resourceType = "Focus", current = rangerTuning.maximumResource, maximum = rangerTuning.maximumResource },
				resourceRegenerationPerSecond = rangerTuning.resourceRegenerationPerSecond,
				physicalAttack = rangerTuning.physicalAttack,
				magicAttack = rangerTuning.magicAttack,
				basePhysicalDefense = rangerTuning.physicalDefense,
				physicalDefense = rangerTuning.physicalDefense,
				baseAttackSpeedMultiplier = rangerTuning.attackSpeedMultiplier,
				attackSpeedMultiplier = rangerTuning.attackSpeedMultiplier,
				criticalChance = rangerTuning.criticalChance,
				baseMovementSpeed = rangerTuning.movementSpeed,
				movementSpeed = rangerTuning.movementSpeed,
			}
			local canonicalSnareEffect = SkillDefinitions.snare.effect
			assert(canonicalSnareEffect.kind == "MovementSlow")
			local shortSnare = table.clone(SkillDefinitions.snare)
			shortSnare.effect = {
				kind = "MovementSlow",
				magnitude = canonicalSnareEffect.magnitude,
				durationSeconds = 0.12,
				refreshDurationOnReapply = true,
			}
			local effectTarget: CombatEffectService.EffectTarget = { kind = "Mob", entityId = entityId, model = mob }
			assert(CombatEffectService.execute(player, effectStats, shortSnare, effectTarget).applied)
			task.wait(0.07)
			assert(CombatEffectService.execute(player, effectStats, shortSnare, effectTarget).applied)
			local recalculatedFixtureSpeed = MobDefinitions.grey_wolf.chaseSpeed + 3
			assert(MobService.setMovementSpeed(entityId, recalculatedFixtureSpeed))
			task.wait(0.07)
			assert(
				humanoid.WalkSpeed == recalculatedFixtureSpeed * (1 - canonicalSnareEffect.magnitude),
				"old snare expiry must not clear the refreshed effect"
			)
			task.wait(0.07)
			assert(humanoid.WalkSpeed == recalculatedFixtureSpeed, "refreshed snare must restore recalculated movement")
			assert(mob:GetAttribute(CombatConfig.MobMovementSlowAttribute) == nil)
			assert(MobService.setMovementSpeed(entityId, MobDefinitions.grey_wolf.chaseSpeed))

			mobRootToRestore = mobRoot
			originalMobPivot = mob:GetPivot()
			originalMobRootAnchored = mobRoot.Anchored
			mobRoot.Anchored = true
			mob:PivotTo(playerRoot.CFrame * CFrame.new(0, 0, -(CombatConfig.BasicAttackRange * 0.5)))
			fixtureReady = true

			local deathCount = 0
			deathConnection = humanoid.Died:Connect(function()
				deathCount += 1
			end)
			waitUntil("client AttackRequest characterization", 12, function(): boolean?
				return if completedByPlayer[player] then true else nil
			end)
			local initialXP = player:GetAttribute("SessionXP") :: number
			assert(MobService.applyDamage(entityId, humanoid.Health, player))
			assert(not MobService.applyDamage(entityId, 1, player), "dead mob must reject repeated damage")

			local expectedXP = initialXP + MobDefinitions.grey_wolf.rewardXP
			waitUntil("one XP reward for the grey wolf death", 3, function(): boolean?
				return if player:GetAttribute("SessionXP") == expectedXP then true else nil
			end)
			assert(deathCount == 1, "mob death must be observed exactly once")

			lifecycleCommand.OnServerInvoke = function(sender: Player, command: unknown): any
				assert(sender == player)
				if command == "PrepareTarget" then
					return prepareLifecycleTarget(player)
				elseif command == "KillTarget" then
					local currentMob = lifecycleMob
					local currentHumanoid = if currentMob ~= nil then currentMob:FindFirstChildOfClass("Humanoid") else nil
					assert(currentHumanoid ~= nil)
					currentHumanoid.Health = 0
					return true
				elseif command == "KillActor" then
					local actorHumanoid = if player.Character ~= nil then player.Character:FindFirstChildOfClass("Humanoid") else nil
					assert(actorHumanoid ~= nil)
					actorHumanoid.Health = 0
					return true
				elseif command == "ReplaceCharacter" then
					player:LoadCharacter()
					return true
				end
				error("unsupported lifecycle command")
			end
			lifecycleStart:FireClient(player)
			waitUntil("manual attack lifecycle client completion", 35, function(): boolean?
				return if lifecycleCompletedByPlayer[player] then true else nil
			end)

			Players.RespawnTime = 0.25
			skillRuntimeCommand.OnServerInvoke = function(sender: Player, command: unknown): any
				assert(sender == player)
				if command == "PrepareTarget" then
					local preparedId = prepareLifecycleTarget(player)
					local preparedHumanoid = if lifecycleMob ~= nil then lifecycleMob:FindFirstChildOfClass("Humanoid") else nil
					assert(preparedHumanoid ~= nil)
					preparedHumanoid.Health = preparedHumanoid.MaxHealth
					return preparedId
				elseif command == "MoveTargetOutOfRange" then
					local currentMob = lifecycleMob
					local playerRoot = if player.Character ~= nil then player.Character:FindFirstChild("HumanoidRootPart") else nil
					assert(currentMob ~= nil and playerRoot ~= nil and playerRoot:IsA("BasePart"))
					currentMob:PivotTo(playerRoot.CFrame * CFrame.new(0, 0, -200))
					return true
				elseif command == "KillActor" then
					local actorHumanoid = if player.Character ~= nil then player.Character:FindFirstChildOfClass("Humanoid") else nil
					assert(actorHumanoid ~= nil)
					actorHumanoid.Health = 0
					return true
				elseif command == "KillTarget" then
					local currentMob = lifecycleMob
					local currentHumanoid = if currentMob ~= nil then currentMob:FindFirstChildOfClass("Humanoid") else nil
					assert(currentHumanoid ~= nil)
					currentHumanoid.Health = 0
					return true
				elseif command == "BecomeRanger" then
					player:SetAttribute(CombatConfig.ArchetypeAttribute, "ranger")
					player:LoadCharacter()
					return true
				elseif command == "BecomeMystic" then
					player:SetAttribute(CombatConfig.ArchetypeAttribute, "mystic")
					player:LoadCharacter()
					return true
				elseif command == "DamageActor" then
					local actorHumanoid = if player.Character ~= nil then player.Character:FindFirstChildOfClass("Humanoid") else nil
					assert(actorHumanoid ~= nil and actorHumanoid.Health > 0)
					actorHumanoid.Health = math.max(1, actorHumanoid.MaxHealth - 40)
					return actorHumanoid.Health
				elseif command == "RemoveTarget" then
					local currentMob = lifecycleMob
					assert(currentMob ~= nil)
					currentMob:Destroy()
					lifecycleMob = nil
					return true
				end
				error("unsupported skill runtime command")
			end
			skillRuntimeStart:FireClient(player)
			waitUntil("authoritative skill runtime client completion", 70, function(): boolean?
				return if skillRuntimeCompletedByPlayer[player] then true else nil
			end)
		end)

		if deathConnection ~= nil then
			deathConnection:Disconnect()
			deathConnection = nil
		end
		if completionConnection ~= nil then
			completionConnection:Disconnect()
			completionConnection = nil
		end
		lifecycleCompletionConnection:Disconnect()
		skillRuntimeCompletionConnection:Disconnect()
		Players.RespawnTime = originalRespawnTime
		fixtureReady = false
		attackContractReady.OnServerInvoke = nil
		lifecycleCommand.OnServerInvoke = nil
		skillRuntimeCommand.OnServerInvoke = nil
		if mobToCleanUp ~= nil and mobToCleanUp.Parent ~= nil and originalMobPivot ~= nil then
			mobToCleanUp:PivotTo(originalMobPivot)
		end
		if mobRootToRestore ~= nil and mobRootToRestore.Parent ~= nil and originalMobRootAnchored ~= nil then
			mobRootToRestore.Anchored = originalMobRootAnchored
		end
		if mobToCleanUp ~= nil and mobToCleanUp.Parent ~= nil then
			mobToCleanUp:Destroy()
		end
		if not ok then
			error(failure, 0)
		end
	end)
end
