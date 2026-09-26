--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PartyConfig = require(ReplicatedStorage.Shared.party.PartyConfig)
local PartyRequestRules = require(ReplicatedStorage.Shared.party.PartyRequestRules)
local PartyService = require(script.Parent.PartyService)

local PartyNetworkService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRequest = remotes:WaitForChild("PartyActionRequest") :: RemoteEvent
local snapshotEvent = remotes:WaitForChild("PartySnapshot") :: RemoteEvent
local inviteEvent = remotes:WaitForChild("PartyInviteReceived") :: RemoteEvent
local resultEvent = remotes:WaitForChild("PartyResult") :: RemoteEvent
local connections: { RBXScriptConnection } = {}
local lastRequestAt: { [Player]: number } = {}
local started = false

local function sendSnapshot(userId: number, value: any?): ()
	local player = Players:GetPlayerByUserId(userId)
	if player then snapshotEvent:FireClient(player, value or { partyId=nil, revision=0, leaderUserId=nil, memberUserIds={} }) end
end

local function handle(player: Player, ...: unknown): ()
	local action, targetUserId, inviteId = PartyRequestRules.validate(
		select("#", ...),
		select(1, ...),
		RunService:IsStudio()
	)
	if action == nil then return end
	local timestamp = workspace:GetServerTimeNow()
	if lastRequestAt[player] and timestamp - lastRequestAt[player] < PartyConfig.RequestCooldownSeconds then return end
	lastRequestAt[player] = timestamp
	local ok, reason = false, nil
	if action == "Invite" then
		local target = Players:GetPlayerByUserId(targetUserId :: number)
		if target == nil or target == player then ok, reason = false, if target == player then "SelfInvite" else "TargetUnavailable"
		else ok, reason = PartyService.invite(player, target) end
	elseif action == "Accept" then ok, reason = PartyService.acceptInvite(player, inviteId :: string)
	elseif action == "Decline" then ok, reason = PartyService.declineInvite(player, inviteId :: string)
	elseif action == "Kick" then ok, reason = PartyService.kick(player, targetUserId :: number)
	elseif action == "Leave" then ok, reason = PartyService.leave(player) end
	resultEvent:FireClient(player, { action=action, ok=ok, reason=reason })
end

function PartyNetworkService.start(): ()
	if started then return end
	started = true
	table.insert(connections, actionRequest.OnServerEvent:Connect(handle))
	table.insert(connections, PartyService.Changed:Connect(sendSnapshot))
	table.insert(connections, PartyService.InviteCreated:Connect(function(target, invite) inviteEvent:FireClient(target, invite) end))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player) lastRequestAt[player] = nil end))
end

function PartyNetworkService.stop(): ()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections); table.clear(lastRequestAt)
end

return PartyNetworkService
