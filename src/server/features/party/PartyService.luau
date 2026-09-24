--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyConfig = require(ReplicatedStorage.Shared.party.PartyConfig)
local PartyRules = require(ReplicatedStorage.Shared.party.PartyRules)
local PlayerDataService = require(script.Parent.Parent.Parent.services.PlayerDataService)

type PartyRecord = {
	id: string,
	revision: number,
	leaderUserId: number,
	memberUserIds: { number },
	nextLootCursor: number,
}
type InviteRecord = {
	id: string,
	inviterUserId: number,
	targetUserId: number,
	createdAt: number,
	inviterPartyId: string?,
}

local PartyService = {}
local changedEvent = Instance.new("BindableEvent")
local inviteEvent = Instance.new("BindableEvent")
PartyService.Changed = changedEvent.Event
PartyService.InviteCreated = inviteEvent.Event

local partiesById: { [string]: PartyRecord } = {}
local partyIdByUserId: { [number]: string } = {}
local pendingInvitesById: { [string]: InviteRecord } = {}
local invitePairCooldown: { [string]: number } = {}
local connections: { RBXScriptConnection } = {}
local started = false

local function now(): number return workspace:GetServerTimeNow() end
local function playerByUserId(userId: number): Player? return Players:GetPlayerByUserId(userId) end
local function pairKey(a: number, b: number): string return tostring(a) .. ":" .. tostring(b) end

local function copyMembers(values: { number }): { number } return table.clone(values) end
local function snapshot(record: PartyRecord): any
	return {
		partyId = record.id,
		revision = record.revision,
		leaderUserId = record.leaderUserId,
		memberUserIds = copyMembers(record.memberUserIds),
	}
end

local function emit(record: PartyRecord?, affected: { number }): ()
	for _, userId in affected do changedEvent:Fire(userId, if record then snapshot(record) else nil) end
end

local function deleteInvitesFor(userId: number): ()
	for id, invite in pendingInvitesById do
		if invite.inviterUserId == userId or invite.targetUserId == userId then pendingInvitesById[id] = nil end
	end
end

local function leaveUserId(userId: number): (boolean, string?)
	deleteInvitesFor(userId)
	local partyId = partyIdByUserId[userId]
	if partyId == nil then return false, "NotInParty" end
	local record = partiesById[partyId]
	if record == nil then partyIdByUserId[userId] = nil; return false, "NotInParty" end
	local affected = copyMembers(record.memberUserIds)
	local nextState = PartyRules.removeMember(record, userId)
	partyIdByUserId[userId] = nil
	if nextState == nil then
		partiesById[partyId] = nil
		for _, memberUserId in record.memberUserIds do partyIdByUserId[memberUserId] = nil end
		emit(nil, affected)
	else
		record.leaderUserId = nextState.leaderUserId
		record.memberUserIds = nextState.memberUserIds
		record.nextLootCursor = nextState.nextLootCursor
		record.revision += 1
		emit(record, affected)
	end
	return true, nil
end

function PartyService.start(): ()
	if started then return end
	started = true
	table.insert(connections, Players.PlayerRemoving:Connect(function(player) leaveUserId(player.UserId); deleteInvitesFor(player.UserId) end))
end

function PartyService.stop(): ()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections); table.clear(partiesById); table.clear(partyIdByUserId)
	table.clear(pendingInvitesById); table.clear(invitePairCooldown)
end

function PartyService.invite(inviter: Player, target: Player): (boolean, string?, any?)
	if inviter == target then return false, "SelfInvite", nil end
	if target.Parent ~= Players then return false, "TargetUnavailable", nil end
	if not PlayerDataService.isReady(inviter) or not PlayerDataService.isReady(target) then return false, "NotReady", nil end
	if partyIdByUserId[target.UserId] ~= nil then return false, "AlreadyInParty", nil end
	local record = if partyIdByUserId[inviter.UserId] then partiesById[partyIdByUserId[inviter.UserId]] else nil
	if not PartyRules.canInvite(record, inviter.UserId, target.UserId) then return false, "NotAllowed", nil end
	local key = pairKey(inviter.UserId, target.UserId)
	local timestamp = now()
	if invitePairCooldown[key] and timestamp - invitePairCooldown[key] < PartyConfig.InvitePairCooldownSeconds then return false, "InviteCooldown", nil end
	invitePairCooldown[key] = timestamp
	local id = HttpService:GenerateGUID(false)
	local invite = { id=id, inviterUserId=inviter.UserId, targetUserId=target.UserId, createdAt=timestamp, inviterPartyId=if record then record.id else nil }
	pendingInvitesById[id] = invite
	inviteEvent:Fire(target, { inviteId=id, inviterUserId=inviter.UserId, inviterName=inviter.DisplayName, expiresAt=timestamp + PartyConfig.InviteTtlSeconds })
	return true, nil, invite
end

function PartyService.acceptInvite(player: Player, inviteId: string): (boolean, string?)
	local invite = pendingInvitesById[inviteId]
	if invite == nil or invite.targetUserId ~= player.UserId then return false, "InvalidInvite" end
	pendingInvitesById[inviteId] = nil
	if PartyRules.isInviteExpired(invite.createdAt, now()) then return false, "ExpiredInvite" end
	local inviter = playerByUserId(invite.inviterUserId)
	if inviter == nil or not PlayerDataService.isReady(player) or not PlayerDataService.isReady(inviter) then return false, "NotReady" end
	if partyIdByUserId[player.UserId] ~= nil then return false, "AlreadyInParty" end
	local currentPartyId = partyIdByUserId[inviter.UserId]
	local record = if currentPartyId then partiesById[currentPartyId] else nil
	local inviterChanged = invite.inviterPartyId ~= currentPartyId or (record ~= nil and record.leaderUserId ~= inviter.UserId)
	if not PartyRules.canAccept(record, false, inviterChanged, true) then return false, "PartyChanged" end
	if record == nil then
		record = { id=HttpService:GenerateGUID(false), revision=1, leaderUserId=inviter.UserId, memberUserIds={ inviter.UserId }, nextLootCursor=1 }
		partiesById[record.id] = record
		partyIdByUserId[inviter.UserId] = record.id
	end
	local nextState = PartyRules.addMember(record, player.UserId)
	if nextState == record then return false, "PartyFull" end
	record.memberUserIds = nextState.memberUserIds; record.revision += 1
	partyIdByUserId[player.UserId] = record.id
	emit(record, record.memberUserIds)
	return true, nil
end

function PartyService.declineInvite(player: Player, inviteId: string): (boolean, string?)
	local invite = pendingInvitesById[inviteId]
	if invite == nil or invite.targetUserId ~= player.UserId then return false, "InvalidInvite" end
	pendingInvitesById[inviteId] = nil
	return true, nil
end

function PartyService.leave(player: Player): (boolean, string?) return leaveUserId(player.UserId) end
function PartyService.getPartyId(player: Player): string? return partyIdByUserId[player.UserId] end
function PartyService.getSnapshot(player: Player): any?
	local id = partyIdByUserId[player.UserId]
	return if id and partiesById[id] then snapshot(partiesById[id]) else nil
end
function PartyService.getOrderedMembers(player: Player): { number }
	local id = partyIdByUserId[player.UserId]
	return if id and partiesById[id] then copyMembers(partiesById[id].memberUserIds) else { player.UserId }
end

function PartyService.resolveEligibleMembers(killer: Player, deathPosition: Vector3): { Player }
	local result = {}
	for _, userId in PartyService.getOrderedMembers(killer) do
		local player = playerByUserId(userId)
		local character = if player then player.Character else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if player and PlayerDataService.isReady(player) and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0
			and (root.Position - deathPosition).Magnitude <= PartyConfig.RewardRadiusStuds then table.insert(result, player) end
	end
	return result
end

function PartyService.selectLootRecipient(killer: Player, eligiblePlayers: { Player }): Player?
	local id = partyIdByUserId[killer.UserId]
	if id == nil then return eligiblePlayers[1] end
	local record = partiesById[id]
	if record == nil then return eligiblePlayers[1] end
	local eligible = {}; for _, player in eligiblePlayers do eligible[player.UserId] = true end
	local userId, nextCursor = PartyRules.selectRoundRobin(record.memberUserIds, eligible, record.nextLootCursor)
	if userId == nil then return nil end
	record.nextLootCursor = nextCursor
	return playerByUserId(userId)
end

return PartyService
