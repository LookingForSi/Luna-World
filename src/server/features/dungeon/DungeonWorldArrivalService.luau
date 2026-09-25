--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.dungeon.DungeonHandoffRules)
local UnlockRules = require(ReplicatedStorage.Shared.dungeon.DungeonUnlockRules)
local QuestDefinitions = require(ReplicatedStorage.Shared.definitions.QuestDefinitions)
local IntentRules = require(ReplicatedStorage.Shared.core.transfer.TransferIntentRules)
local Config = require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local Store = require(script.Parent.DungeonHandoffStore)
local IntentStore = require(script.Parent.Parent.Parent.core.transfer.MemoryStoreTransferIntentStore)
local PlayerData = require(script.Parent.Parent.Parent.services.PlayerDataService)
local PartyService = require(script.Parent.Parent.party.PartyService)
local Diagnostics = require(script.Parent.DungeonDiagnostics)

local Service = {}
local contracts: { [Player]: any } = {}
local connections = {}
local intents = IntentStore.new()
local sessions: { [string]: any } = {}

function Service.isPayload(player: Player): boolean
	return Rules.isRoutingPayload(player:GetJoinData().TeleportData, "World")
end

function Service.admit(player: Player): (boolean, string?)
	local data = player:GetJoinData().TeleportData
	local contract = Store.get(data.dungeonToken)
	local ok, reason = Rules.validate(contract, os.time(), "World", player.UserId)
	if not ok or contract.kind ~= "DungeonReturn" then
		Diagnostics.reject("RETURN_HANDOFF", { userId = player.UserId, reason = reason })
		return false, reason or "WrongKind"
	end
	if contract.returnMode ~= nil and contract.returnMode ~= "Completed" and contract.returnMode ~= "Retreat" then
		Diagnostics.reject("RETURN_HANDOFF", { userId = player.UserId, reason = "InvalidReturnMode" })
		return false, "InvalidReturnMode"
	end
	contracts[player] = contract
	return true, nil
end

local function reconstruct(contract: any): ()
	local id = contract.runId
	if sessions[id] then return end
	sessions[id] = true
	task.delay(Config.PartyReconstructionDelaySeconds, function()
		local ok = PartyService.restoreTrusted(id, contract.leaderUserId, contract.memberUserIds)
		if not ok then sessions[id] = nil end
	end)
end

local function reactivateWardenGate(player: Player, contract: any): boolean
	if contract.returnMode ~= "Retreat" then return true end
	local changed = false
	local mutated, reason = PlayerData.mutate(player, function(profile)
		changed = UnlockRules.prepareRetry(profile.Quests, QuestDefinitions[UnlockRules.QuestId])
	end)
	if not mutated then
		Diagnostics.reject("RETREAT_QUEST_RESET", { runId = contract.runId, userId = player.UserId, reason = reason })
		return false
	end
	if changed then
		Diagnostics.event("RETREAT_QUEST_REACTIVATED", { runId = contract.runId, userId = player.UserId, questId = UnlockRules.QuestId })
	end
	return true
end

local function arrive(player: Player): ()
	local contract = contracts[player]
	if not contract then return end
	local profile = contract.profiles[tostring(player.UserId)]
	local intent, why = intents:consume(profile.transferId, {
		userId = player.UserId,
		characterId = profile.characterId,
		destinationRole = "World",
		entryPointId = "luna_village",
	})
	if not intent then PlayerData.failSession(player, why or "ReturnIntentMissing"); return end
	local valid = IntentRules.validate(intent, os.time(), "World")
	if not valid then PlayerData.failSession(player, "ReturnIntentInvalid"); return end
	local selected, reason = PlayerData.selectCharacter(player, profile.characterId)
	if not selected or not PlayerData.confirmArrival(player) then
		PlayerData.failSession(player, reason or "ReturnActivationFailed")
		return
	end
	if not reactivateWardenGate(player, contract) then
		PlayerData.failSession(player, "RetreatQuestResetFailed")
		return
	end
	reconstruct(contract)
	Store.removeRejoin(player.UserId)
	Diagnostics.event("RETURN_COMPLETED", { runId = contract.runId, userId = player.UserId, mode = contract.returnMode or "Completed" })
end

function Service.start(): ()
	table.insert(connections, PlayerData.AccountReady:Connect(arrive))
	for _, player in Players:GetPlayers() do
		if PlayerData.isAccountReady(player) then task.spawn(arrive, player) end
	end
end

function Service.stop(): ()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	table.clear(contracts)
	table.clear(sessions)
end

return Service
