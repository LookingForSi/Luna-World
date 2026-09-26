--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.config.SessionGuardConfig)
local Rules = require(ReplicatedStorage.Shared.session.SessionGuardRules)
local PlayerDataService = require(script.Parent.Parent.services.PlayerDataService)
local MemoryStoreSessionGuardStore = require(script.Parent.MemoryStoreSessionGuardStore)

local Service = {}

type ActiveSession = {
	sessionId: string,
	jobId: string,
	handoffPending: boolean,
}

local sessions: { [Player]: ActiveSession } = {}
local connections: { RBXScriptConnection } = {}
local store: any = nil
local started = false
local generation = 0

local function kick(player: Player, message: string): ()
	task.defer(function()
		if player.Parent == Players then
			player:Kick(message)
		end
	end)
end

local function releasePlayer(player: Player): ()
	local session = sessions[player]
	sessions[player] = nil
	if session == nil or store == nil then return end
	-- Once a server-authoritative teleport has started, keep the short lease alive
	-- for the destination. Releasing here would create a gap where a second device
	-- could steal the account between source PlayerRemoving and destination admission.
	if session.handoffPending then return end
	local ok, reason = store:release(player.UserId, session.sessionId, session.jobId)
	if not ok and reason ~= "Moved" and reason ~= "Busy" then
		warn(string.format("SessionGuard release failed for %s: %s", player.Name, tostring(reason)))
	end
end

function Service.admit(player: Player): (boolean, string?)
	if RunService:IsStudio() then return true, nil end
	local existing = sessions[player]
	if existing ~= nil then return true, nil end
	if store == nil then
		kick(player, Config.GuardUnavailableKickMessage)
		return false, "SessionGuardUnavailable"
	end

	local joinData = player:GetJoinData()
	local routed = Rules.readRoutedSessionId(joinData.TeleportData, player.UserId)
	local sessionId = routed or HttpService:GenerateGUID(false)
	local ok, reason = store:claim(
		player.UserId,
		sessionId,
		game.JobId,
		os.time(),
		Config.LeaseSeconds
	)
	if not ok then
		if reason == "Busy" then
			kick(player, Config.ConflictKickMessage)
			return false, "DuplicateExperienceSession"
		end
		kick(player, Config.GuardUnavailableKickMessage)
		return false, reason or "SessionGuardClaimFailed"
	end

	sessions[player] = {
		sessionId = sessionId,
		jobId = game.JobId,
		handoffPending = false,
	}
	return true, nil
end

function Service.getSessionId(player: Player): string?
	local session = sessions[player]
	return if session ~= nil then session.sessionId else nil
end

function Service.beginHandoff(players: { Player }): (boolean, string?)
	for _, player in players do
		local session = sessions[player]
		if session == nil then return false, "SessionGuardMissing" end
	end
	for _, player in players do
		(sessions[player] :: ActiveSession).handoffPending = true
	end
	return true, nil
end

function Service.cancelHandoff(players: { Player }): ()
	for _, player in players do
		local session = sessions[player]
		if session ~= nil then session.handoffPending = false end
	end
end

function Service.attachRoutingPayload(payload: any, players: { Player }): (any?, string?)
	if typeof(payload) ~= "table" then return nil, "InvalidRoutingPayload" end
	local routed = table.clone(payload)
	local ids = {}
	for _, player in players do
		local session = sessions[player]
		if session == nil then return nil, "SessionGuardMissing" end
		ids[tostring(player.UserId)] = session.sessionId
	end
	routed.experienceSessionIds = ids
	return routed, nil
end

function Service.start(): ()
	if started then return end
	started = true
	generation += 1
	if RunService:IsStudio() then return end

	store = MemoryStoreSessionGuardStore.new()
	PlayerDataService.setAdmissionValidator("SessionGuard", Service.admit)
	table.insert(connections, Players.PlayerRemoving:Connect(releasePlayer))

	local myGeneration = generation
	task.spawn(function()
		while started and generation == myGeneration do
			task.wait(Config.HeartbeatSeconds)
			if not started or generation ~= myGeneration or store == nil then break end
			for player, session in sessions do
				if player.Parent == Players and not session.handoffPending then
					local ok, reason = store:renew(
						player.UserId,
						session.sessionId,
						session.jobId,
						os.time(),
						Config.LeaseSeconds
					)
					if not ok then
						if reason == "Moved" or reason == "Busy" or reason == "Missing" then
							sessions[player] = nil
							kick(player, Config.ConflictKickMessage)
						else
							warn(string.format("SessionGuard heartbeat failed for %s: %s", player.Name, tostring(reason)))
						end
					end
				end
			end
		end
	end)
end

function Service.stop(): ()
	if not started then return end
	started = false
	generation += 1
	if not RunService:IsStudio() then
		PlayerDataService.setAdmissionValidator("SessionGuard", nil)
	end
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)

	local players = {}
	for player in sessions do table.insert(players, player) end
	for _, player in players do releasePlayer(player) end
	table.clear(sessions)
	store = nil
end

return Service
