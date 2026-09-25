--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local UnlockRules = require(ReplicatedStorage.Shared.dungeon.DungeonUnlockRules)
local QuestDefinitions = require(ReplicatedStorage.Shared.definitions.QuestDefinitions)
local DungeonTransfer = require(script.Parent.DungeonTransferService)
local DungeonWorld = require(script.Parent.DungeonWorldService)
local DungeonRun = require(script.Parent.DungeonRunService)
local Encounters = require(script.Parent.DungeonEncounterService)
local Diagnostics = require(script.Parent.DungeonDiagnostics)
local PlayerData = require(script.Parent.Parent.Parent.services.PlayerDataService)
local TraversalRecovery = require(script.Parent.Parent.Parent.world.TraversalRecovery)

local Service = {}
local active = false
local participantIds: { [number]: boolean } = {}
local exitConnection: RBXScriptConnection? = nil
local retreatConnection: RBXScriptConnection? = nil
local actionConnection: RBXScriptConnection? = nil
local rootConnection: RBXScriptConnection? = nil
local retreatConfirmations: { [Player]: any } = {}

local event = ReplicatedStorage.Remotes:WaitForChild("DungeonEvent") :: RemoteEvent
local action = ReplicatedStorage.Remotes:WaitForChild("DungeonAction") :: RemoteEvent

local function disconnectRuntimeSignals(): ()
	if exitConnection ~= nil then exitConnection:Disconnect(); exitConnection = nil end
	if retreatConnection ~= nil then retreatConnection:Disconnect(); retreatConnection = nil end
	if actionConnection ~= nil then actionConnection:Disconnect(); actionConnection = nil end
	if rootConnection ~= nil then rootConnection:Disconnect(); rootConnection = nil end
	table.clear(retreatConfirmations)
end

local function close(returnToMoonfallSpawn: boolean?): ()
	if not active then return end
	active = false
	disconnectRuntimeSignals()
	Encounters.stop()
	DungeonRun.stop()
	DungeonWorld.stop()

	local destination = if returnToMoonfallSpawn then workspace:FindFirstChild("LunaVillageSpawn", true) else nil
	for _, player in Players:GetPlayers() do
		if participantIds[player.UserId] then
			if destination ~= nil and destination:IsA("BasePart") and player.Character ~= nil then
				player.Character:PivotTo(destination.CFrame + Vector3.new(0, 4, 0))
			end
			TraversalRecovery.setPlayerExcluded(player, false)
		end
	end
	table.clear(participantIds)
	Diagnostics.event("RETURN_COMPLETED", { mode = "DevCombined" })
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

local function requestRetreat(player: Player): ()
	local eligible, reason = retreatEligible(player)
	if not eligible then event:FireClient(player, { state = "FAILED", message = reason }); return end
	local snapshot = DungeonRun.getSnapshot()
	if snapshot == nil then return end
	local token = HttpService:GenerateGUID(false)
	retreatConfirmations[player] = {
		token = token,
		expiresAt = os.clock() + Config.ConfirmationTtlSeconds,
	}
	event:FireClient(player, {
		state = "CONFIRM_RETREAT",
		message = if #snapshot.participants > 1
			then "Прервать текущее прохождение для всей группы и вернуться в Moonfall?"
			else "Прервать текущее прохождение и вернуться в Moonfall?",
		retreatToken = token,
	})
end

local function applyRetreatProgression(): ()
	for _, player in Players:GetPlayers() do
		if participantIds[player.UserId] and PlayerData.isReady(player) then
			local changed = false
			local ok, reason = PlayerData.mutate(player, function(profile)
				changed = UnlockRules.prepareRetry(profile.Quests, QuestDefinitions[UnlockRules.QuestId])
			end)
			if not ok then
				Diagnostics.reject("RETREAT_QUEST_RESET", { userId = player.UserId, reason = reason })
			elseif changed then
				Diagnostics.event("RETREAT_QUEST_REACTIVATED", { userId = player.UserId, questId = UnlockRules.QuestId })
			end
		end
	end
end

local function enter(_leader: Player, contract: any): ()
	if active and DungeonWorld.getRoot() == nil then close() end
	if active then return end
	active = true
	for _, userId in contract.memberUserIds do participantIds[userId] = true end

	local ok, reason = pcall(function()
		DungeonWorld.start(true)
		DungeonRun.start()
		for _, player in Players:GetPlayers() do
			if participantIds[player.UserId] then
				TraversalRecovery.setPlayerExcluded(player, true)
				local admitted, admitReason = DungeonRun.admit(player, contract)
				assert(admitted, "DevCombined dungeon admission failed: " .. tostring(admitReason))
			end
		end
		Encounters.start()

		local dungeonRoot = DungeonWorld.getRoot()
		assert(dungeonRoot ~= nil, "DevCombined dungeon root was not created")
		rootConnection = dungeonRoot.AncestryChanged:Connect(function(_, parent)
			if active and parent == nil then task.defer(close, false) end
		end)

		local exit = dungeonRoot:FindFirstChild(Config.ExitPromptName)
		local exitPrompt = if exit ~= nil then exit:FindFirstChildOfClass("ProximityPrompt") else nil
		assert(exitPrompt ~= nil, "DevCombined dungeon exit prompt is missing")
		exitConnection = exitPrompt.Triggered:Connect(function(player)
			local snapshot = DungeonRun.getSnapshot()
			if DungeonRun.isParticipant(player) and snapshot ~= nil and snapshot.state == "COMPLETED" then close(true) end
		end)

		local retreatPrompt = DungeonWorld.getRetreatPrompt()
		assert(retreatPrompt ~= nil, "DevCombined dungeon retreat prompt is missing")
		retreatConnection = retreatPrompt.Triggered:Connect(requestRetreat)

		actionConnection = action.OnServerEvent:Connect(function(player, payload)
			if typeof(payload) ~= "table" or payload.action ~= "Retreat" then return end
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
			local eligible = retreatEligible(player)
			if not eligible then return end
			applyRetreatProgression()
			close(true)
		end)
	end)
	if not ok then
		warn("DevCombined dungeon entry failed: " .. tostring(reason))
		close()
	end
end

function Service.start(): ()
	assert(RunService:IsStudio(), "DevCombined dungeon adapter is Studio-only")
	DungeonTransfer.setStudioHandler(enter)
end

function Service.stop(): ()
	DungeonTransfer.setStudioHandler(nil)
	close()
	disconnectRuntimeSignals()
	table.clear(participantIds)
end

return Service
