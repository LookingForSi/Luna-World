--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local TransferConfig = require(ReplicatedStorage.Shared.config.TransferConfig)
local PlaceConfig = require(ReplicatedStorage.Shared.config.PlaceConfig)
local PlaceRole = require(ReplicatedStorage.Shared.core.runtime.PlaceRole)
local Rules = require(ReplicatedStorage.Shared.dungeon.DungeonHandoffRules)
local PlayerData = require(script.Parent.Parent.Parent.services.PlayerDataService)
local SessionGuardService = require(script.Parent.Parent.Parent.session.SessionGuardService)
local IntentStore = require(script.Parent.Parent.Parent.core.transfer.MemoryStoreTransferIntentStore)
local DungeonRun = require(script.Parent.DungeonRunService)
local DungeonWorld = require(script.Parent.DungeonWorldService)
local Store = require(script.Parent.DungeonHandoffStore)
local Diagnostics = require(script.Parent.DungeonDiagnostics)

local Service = {}
local exitConnection: RBXScriptConnection? = nil
local retreatConnection: RBXScriptConnection? = nil
local actionConnection: RBXScriptConnection? = nil
local failureConnection: RBXScriptConnection? = nil
local pending: { [Player]: any } = {}
local retreatConfirmations: { [Player]: any } = {}
local intents = IntentStore.new()
local returnInProgress = false

local event = ReplicatedStorage.Remotes:WaitForChild("DungeonEvent") :: RemoteEvent
local action = ReplicatedStorage.Remotes:WaitForChild("DungeonAction") :: RemoteEvent

local function send(player: Player, state: string, message: string?, extra: any?): ()
	local payload = extra or {}
	payload.state = state
	payload.message = message
	event:FireClient(player, payload)
end

local function recover(player: Player, record: any): ()
	if pending[player] ~= record then return end
	SessionGuardService.cancelHandoff({ player })
	pending[player] = nil
	returnInProgress = false
	local profile = record.profiles[tostring(player.UserId)]
	if profile then intents:remove(profile.transferId) end
	if player.Parent == Players then
		PlayerData.recoverTransfer(player, true)
		send(player, "RETURN_RETRY", "Не удалось вернуться в Moonfall. Попробуйте снова.")
	end
end

local function retreatEligible(player: Player): (boolean, string?)
	local snapshot = DungeonRun.getSnapshot()
	if snapshot == nil or not DungeonRun.isParticipant(player) then return false, "Вы не участвуете в текущем прохождении." end
	if snapshot.state ~= "ACTIVE" and snapshot.state ~= "BOSS" then return false, "Текущее прохождение уже нельзя прервать." end
	if #snapshot.participants > 1 and snapshot.leaderUserId ~= player.UserId then
		return false, "Только лидер группы может прервать прохождение."
	end
	return true, nil
end

local function begin(player: Player, mode: string): ()
	if returnInProgress then return end
	local snapshot = DungeonRun.getSnapshot()
	local source = DungeonRun.getContract()
	if snapshot == nil or source == nil or not DungeonRun.isParticipant(player) or pending[player] then return end

	if mode == "Completed" then
		if snapshot.state ~= "COMPLETED" then return end
	elseif mode == "Retreat" then
		local eligible, reason = retreatEligible(player)
		if not eligible then send(player, "FAILED", reason); return end
	else
		return
	end

	returnInProgress = true
	local destination = PlaceConfig.getPlaceId(game.GameId, PlaceRole.World)
	if not destination then
		returnInProgress = false
		send(player, "FAILED", "Moonfall Place не настроен.")
		return
	end

	local current = {}
	for _, candidate in Players:GetPlayers() do
		if DungeonRun.isParticipant(candidate) and PlayerData.isReady(candidate) then
			table.insert(current, candidate)
		end
	end
	if #current == 0 then returnInProgress = false; return end

	local token = HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false)
	local now = os.time()
	local profiles = {}
	local prepared = {}
	for _, candidate in current do
		local characterId = PlayerData.getActiveCharacterId(candidate)
		if not characterId then continue end
		local transferId = HttpService:GenerateGUID(false)
		local ok = PlayerData.beginTransfer(candidate)
		if not ok then
			for _, old in prepared do PlayerData.recoverTransfer(old, true) end
			returnInProgress = false
			return
		end
		table.insert(prepared, candidate)
		local intent = {
			transferVersion = TransferConfig.Version,
			transferId = transferId,
			userId = candidate.UserId,
			characterId = characterId,
			sourceRole = "Dungeon",
			destinationRole = "World",
			entryPointId = "luna_village",
			expiresAt = now + Config.ReturnTtlSeconds,
		}
		if not intents:create(intent, Config.ReturnTtlSeconds) then
			for _, old in prepared do PlayerData.recoverTransfer(old, true) end
			returnInProgress = false
			return
		end
		profiles[tostring(candidate.UserId)] = { transferId = transferId, characterId = characterId }
	end

	local contract = {
		schemaVersion = Config.SchemaVersion,
		kind = "DungeonReturn",
		returnMode = mode,
		runId = snapshot.runId,
		nonce = token,
		sourceRole = "Dungeon",
		destinationRole = "World",
		leaderUserId = source.leaderUserId,
		memberUserIds = source.memberUserIds,
		profiles = profiles,
		issuedAt = now,
		expiresAt = now + Config.ReturnTtlSeconds,
	}
	if not Store.put(token, contract, Config.ReturnTtlSeconds) then
		for _, old in prepared do PlayerData.recoverTransfer(old, true) end
		returnInProgress = false
		return
	end

	local record = { profiles = profiles, mode = mode }
	for _, candidate in current do
		pending[candidate] = record
		send(candidate, "RETURNING", if mode == "Retreat" then "Группа покидает Руины Селены..." else "Возвращение в Moonfall...")
	end
	Diagnostics.event(if mode == "Retreat" then "RETREAT_STARTED" else "RETURN_STARTED", {
		runId = snapshot.runId,
		count = #current,
	})

	local routingPayload, routingReason = SessionGuardService.attachRoutingPayload(
		Rules.routingPayload(token, contract),
		current
	)
	if routingPayload == nil then
		for _, candidate in current do recover(candidate, record) end
		Diagnostics.reject("RETURN_SESSION_GUARD", {
			runId = snapshot.runId,
			reason = routingReason or "SessionGuardRoutingFailed",
		})
		return
	end
	local handoffOk, handoffReason = SessionGuardService.beginHandoff(current)
	if not handoffOk then
		for _, candidate in current do recover(candidate, record) end
		Diagnostics.reject("RETURN_SESSION_GUARD", {
			runId = snapshot.runId,
			reason = handoffReason or "SessionGuardHandoffFailed",
		})
		return
	end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(routingPayload)
	local ok = pcall(function()
		TeleportService:TeleportAsync(destination, current, options)
	end)
	if not ok then
		for _, candidate in current do recover(candidate, record) end
	elseif mode == "Retreat" then
		for _, userId in snapshot.participants do Store.removeRejoin(userId) end
	end
end

local function requestRetreat(player: Player): ()
	local eligible, reason = retreatEligible(player)
	if not eligible then send(player, "FAILED", reason); return end
	local snapshot = DungeonRun.getSnapshot()
	if snapshot == nil then return end
	local token = HttpService:GenerateGUID(false)
	local now = os.clock()
	retreatConfirmations[player] = {
		token = token,
		expiresAt = now + Config.ConfirmationTtlSeconds,
	}
	local message = if #snapshot.participants > 1
		then "Прервать текущее прохождение для всей группы и вернуться в Moonfall?"
		else "Прервать текущее прохождение и вернуться в Moonfall?"
	send(player, "CONFIRM_RETREAT", message, { retreatToken = token })
end

function Service.start(): ()
	local root = DungeonWorld.getRoot()
	local exit = if root ~= nil then root:FindFirstChild(Config.ExitPromptName) else nil
	local exitPrompt = if exit ~= nil then exit:FindFirstChildOfClass("ProximityPrompt") else nil
	if exitPrompt then exitConnection = exitPrompt.Triggered:Connect(function(player) begin(player, "Completed") end) end

	local retreatPrompt = DungeonWorld.getRetreatPrompt()
	if retreatPrompt then retreatConnection = retreatPrompt.Triggered:Connect(requestRetreat) end

	actionConnection = action.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then return end
		if payload.action == "Return" then
			begin(player, "Completed")
		elseif payload.action == "Retreat" then
			local confirmation = retreatConfirmations[player]
			retreatConfirmations[player] = nil
			if typeof(payload.retreatToken) ~= "string"
				or confirmation == nil
				or payload.retreatToken ~= confirmation.token
				or os.clock() > confirmation.expiresAt
			then
				Diagnostics.reject("RETREAT_CONFIRMATION", { userId = player.UserId, reason = "ExpiredOrSpoofed" })
				return
			end
			begin(player, "Retreat")
		end
	end)

	failureConnection = TeleportService.TeleportInitFailed:Connect(function(player)
		local record = pending[player]
		if record then recover(player, record) end
	end)
end

function Service.stop(): ()
	if exitConnection then exitConnection:Disconnect(); exitConnection = nil end
	if retreatConnection then retreatConnection:Disconnect(); retreatConnection = nil end
	if actionConnection then actionConnection:Disconnect(); actionConnection = nil end
	if failureConnection then failureConnection:Disconnect(); failureConnection = nil end
	table.clear(pending)
	table.clear(retreatConfirmations)
	returnInProgress = false
end

return Service
