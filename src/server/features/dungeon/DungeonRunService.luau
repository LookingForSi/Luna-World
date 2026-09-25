--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rules = require(ReplicatedStorage.Shared.dungeon.DungeonRunRules)
local Config = require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local Progression = require(script.Parent.Parent.Parent.services.ProgressionService)
local Inventory = require(script.Parent.Parent.Parent.services.InventoryService)
local PlayerData = require(script.Parent.Parent.Parent.services.PlayerDataService)
local RespawnService = require(script.Parent.Parent.Parent.services.RespawnService)
local Store = require(script.Parent.DungeonHandoffStore)
local Diagnostics = require(script.Parent.DungeonDiagnostics)
local DungeonWorld = require(script.Parent.DungeonWorldService)

local Service = {}
local run: any = nil
local connections: { RBXScriptConnection } = {}
local characterProtected: { [Player]: boolean } = {}
local oobCharacters: { [Model]: boolean } = {}
local unavailableParticipants: { [number]: boolean } = {}
local deathBatchGeneration = 0
local wipeLatched = false
local missingWorldReported = false

local changed = Instance.new("BindableEvent")
local wipe = Instance.new("BindableEvent")
Service.Changed = changed.Event
Service.Wipe = wipe.Event

local event = ReplicatedStorage.Remotes:WaitForChild("DungeonEvent") :: RemoteEvent
local objectives = {
	"Очистите внешний зал",
	"Победите Стража руин",
	"Пройдите во внутреннее святилище",
	"Победите Падшего Стража Селены",
	"Подземелье завершено",
}

local function log(name: string, fields: any?): () Diagnostics.event(name, fields) end

local function broadcast(state: string, message: string?, extra: any?): ()
	local payload = extra or {}
	payload.state = state
	payload.message = message
	if run ~= nil then
		payload.runId = run.runId
		payload.encounter = run.encounter
		payload.objective = objectives[math.min(run.encounter + 1, #objectives)]
	end
	for _, player in Players:GetPlayers() do
		if run ~= nil and run.memberSet[player.UserId] then event:FireClient(player, payload) end
	end
end

local function transition(to: string): boolean
	if run == nil or not Rules.canTransition(run.state, to) then return false end
	run.state = to
	changed:Fire(Service.getSnapshot())
	return true
end

local function checkpoint(): BasePart?
	return DungeonWorld.getCheckpoint(Rules.checkpointForEncounter(if run ~= nil then run.encounter else 0))
end

local function clearRespawnContext(player: Player): ()
	if run ~= nil then RespawnService.clearContext(player, "dungeon:" .. run.runId) end
	characterProtected[player] = nil
	unavailableParticipants[player.UserId] = nil
end

local function scheduleWipeCheck(): ()
	deathBatchGeneration += 1
	local expectedGeneration = deathBatchGeneration
	task.delay(0.25, function()
		if run == nil or expectedGeneration ~= deathBatchGeneration or wipeLatched then return end
		if not Rules.allDead(run.participants, run.alive, run.connected) then return end
		wipeLatched = true
		run.resetGeneration += 1
		log("PARTY_WIPE", { runId = run.runId, encounterId = run.encounter + 1, resetGeneration = run.resetGeneration })
		broadcast("WIPE", "Группа погибла. Возвращение к последней точке...")
		wipe:Fire(run.encounter + 1, run.resetGeneration)
	end)
end

local function onParticipantDeath(player: Player, _character: Model): ()
	if run == nil or (run.state ~= "ACTIVE" and run.state ~= "BOSS") then return end
	if not run.memberSet[player.UserId] or run.alive[player.UserId] == false then return end
	run.alive[player.UserId] = false
	characterProtected[player] = true
	scheduleWipeCheck()
end

local function onParticipantPlaced(player: Player, character: Model): ()
	if run == nil or not run.memberSet[player.UserId] then return end
	run.alive[player.UserId] = true
	characterProtected[player] = false
	oobCharacters[character] = nil
	unavailableParticipants[player.UserId] = nil
	wipeLatched = false
	local root = character:FindFirstChild("HumanoidRootPart")
	local cp = checkpoint()
	log("DUNGEON_RESPAWN_PLACED", {
		runId = run.runId,
		userId = player.UserId,
		checkpointIndex = Rules.checkpointForEncounter(run.encounter),
		checkpointWorldPosition = if cp ~= nil then cp.Position else "missing",
		characterWorldPosition = if root ~= nil and root:IsA("BasePart") then root.Position else character:GetPivot().Position,
	})
end

local function onContextUnavailable(player: Player): ()
	characterProtected[player] = true
	unavailableParticipants[player.UserId] = true
	Diagnostics.reject("RESPAWN_CONTEXT_UNAVAILABLE", {
		runId = if run ~= nil then run.runId else "none",
		userId = player.UserId,
		checkpointIndex = if run ~= nil then Rules.checkpointForEncounter(run.encounter) else -1,
	})
end

local function installRespawnContext(player: Player): boolean
	if run == nil then return false end
	local contextId = "dungeon:" .. run.runId
	return RespawnService.setContext(player, {
		id = contextId,
		resolveAnchor = checkpoint,
		onDeath = function(character) onParticipantDeath(player, character) end,
		onPlaced = function(character) onParticipantPlaced(player, character) end,
		onUnavailable = function() onContextUnavailable(player) end,
	})
end

function Service.create(contract: any): boolean
	if run ~= nil then return run.runId == contract.runId end
	local ok = Rules.validateParticipants(contract.memberUserIds, contract.leaderUserId)
	if not ok then return false end
	local memberSet = {}
	for _, userId in contract.memberUserIds do memberSet[userId] = true end
	run = {
		runId = contract.runId,
		leaderUserId = contract.leaderUserId,
		participants = table.clone(contract.memberUserIds),
		memberSet = memberSet,
		contract = contract,
		createdAt = os.time(),
		expiresAt = os.time() + Config.RunTtlSeconds,
		state = "CREATED",
		encounter = 0,
		bossDead = false,
		claimed = {},
		arrived = {},
		connected = {},
		alive = {},
		resetGeneration = 0,
	}
	transition("ENTERING")
	log("RUN_CREATED", { runId = run.runId, leaderUserId = run.leaderUserId })
	return true
end

function Service.admit(player: Player, contract: any): (boolean, string?)
	if not Service.create(contract) or run.runId ~= contract.runId then return false, "WrongRun" end
	if not run.memberSet[player.UserId] then return false, "NotParticipant" end
	run.arrived[player.UserId] = true
	run.connected[player.UserId] = true
	run.alive[player.UserId] = true
	characterProtected[player] = true
	if not installRespawnContext(player) then return false, "RespawnServiceUnavailable" end
	if run.state == "ENTERING" then
		transition("ACTIVE")
		log("ENCOUNTER_STARTED", { runId = run.runId, encounterId = 1 })
	end
	if not RespawnService.placeAtContext(player) then
		RespawnService.clearContext(player, "dungeon:" .. run.runId)
		characterProtected[player] = true
		unavailableParticipants[player.UserId] = true
		return false, "DungeonCheckpointUnavailable"
	end
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local cp = checkpoint()
	log("PLAYER_ADMISSION_PLACED", {
		runId = run.runId,
		userId = player.UserId,
		dungeonOrigin = DungeonWorld.getOrigin(),
		checkpointWorldPosition = if cp ~= nil then cp.Position else "missing",
		characterWorldPosition = if root ~= nil and root:IsA("BasePart") then root.Position else "missing",
	})
	broadcast("ACTIVE", nil)
	return true, nil
end

function Service.recordEncounter(index: number): boolean
	local nextEncounter, ok = Rules.advanceEncounter(if run ~= nil then run.encounter else 0, index, false)
	if not ok then return false end
	run.encounter = nextEncounter
	log("ENCOUNTER_COMPLETED", { runId = run.runId, encounterId = index })
	if index == 3 then transition("BOSS"); log("BOSS_STARTED", { runId = run.runId }) end
	changed:Fire(Service.getSnapshot())
	broadcast("ACTIVE", nil)
	return true
end

function Service.completeBoss(): boolean
	if run == nil or run.state ~= "BOSS" or run.bossDead then return false end
	run.bossDead = true
	run.encounter = 4
	transition("COMPLETED")
	log("DUNGEON_COMPLETED", { runId = run.runId })
	broadcast("COMPLETED", "РУИНЫ СЕЛЕНЫ ПРОЙДЕНЫ", { reward = { xp = Config.CompletionXP, luna = Config.CompletionLuna, itemId = Config.CompletionItemId } })
	return true
end

function Service.claimReward(player: Player): boolean
	if run == nil or run.state ~= "COMPLETED" or not run.memberSet[player.UserId] then return false end
	local ok, nextClaims = Rules.claim(run.claimed, player.UserId)
	if not ok then return false end
	run.claimed = nextClaims
	Progression.awardXP(player, Config.CompletionXP)
	PlayerData.mutate(player, function(profile) profile.Luna += Config.CompletionLuna end)
	Inventory.grantItem(player, Config.CompletionItemId, 1)
	log("REWARD_CLAIMED", { runId = run.runId, userId = player.UserId })
	return true
end

function Service.getSnapshot(): any
	if run == nil then return nil end
	return { runId = run.runId, state = run.state, encounter = run.encounter, bossDead = run.bossDead, leaderUserId = run.leaderUserId, participants = table.clone(run.participants), resetGeneration = run.resetGeneration }
end
function Service.getContract(): any return if run ~= nil then run.contract else nil end
function Service.isParticipant(player: Player): boolean return run ~= nil and run.memberSet[player.UserId] == true end

function Service.start(): ()
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		if run == nil or not run.memberSet[player.UserId] then return end
		clearRespawnContext(player)
		run.connected[player.UserId] = nil
		run.alive[player.UserId] = nil
		if run.state == "ACTIVE" or run.state == "BOSS" then
			Store.putRejoin(player.UserId, { schemaVersion = Config.SchemaVersion, userId = player.UserId, runId = run.runId, state = run.state, accessCode = run.contract.accessCode, leaderUserId = run.leaderUserId, memberUserIds = run.participants, expiresAt = os.time() + Config.RejoinTtlSeconds })
			if Rules.allDead(run.participants, run.alive, run.connected) then scheduleWipeCheck() end
		end
	end))
	table.insert(connections, RunService.Heartbeat:Connect(function()
		if run == nil or (run.state ~= "ACTIVE" and run.state ~= "BOSS") then return end
		if DungeonWorld.getRoot() == nil then
			if not missingWorldReported then
				missingWorldReported = true
				Diagnostics.reject("DUNGEON_WORLD_UNAVAILABLE", { runId = run.runId })
			end
			return
		end
		for _, player in Players:GetPlayers() do
			if not run.memberSet[player.UserId] or characterProtected[player] or unavailableParticipants[player.UserId] then continue end
			local character = player.Character
			local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
			local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if character == nil or humanoid == nil or humanoid.Health <= 0 or rootPart == nil or not rootPart:IsA("BasePart") or oobCharacters[character] then continue end
			local within, boundary, localPosition = DungeonWorld.inspectBounds(rootPart.Position)
			if not within then
				oobCharacters[character] = true
				characterProtected[player] = true
				log("PLAYER_OUT_OF_BOUNDS", { runId = run.runId, userId = player.UserId, characterWorldPosition = rootPart.Position, localPosition = localPosition, boundary = boundary, checkpointIndex = Rules.checkpointForEncounter(run.encounter) })
				humanoid.Health = 0
			end
		end
	end))
end

function Service.stop(): ()
	for _, connection in connections do connection:Disconnect() end
	for _, player in Players:GetPlayers() do
		if run ~= nil and run.memberSet[player.UserId] then clearRespawnContext(player) end
	end
	table.clear(connections)
	table.clear(characterProtected)
	table.clear(oobCharacters)
	table.clear(unavailableParticipants)
	if run ~= nil then log("RUN_CLOSED", { runId = run.runId }) end
	run = nil
	deathBatchGeneration += 1
	wipeLatched = false
	missingWorldReported = false
end

return Service
