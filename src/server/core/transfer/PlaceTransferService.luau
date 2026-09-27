--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.core.transfer.TransferIntentRules)
local TransferConfig = require(ReplicatedStorage.Shared.config.TransferConfig)

local Service = {}
Service.__index = Service

function Service.new(deps: any): any
	return setmetatable({
		data = deps.playerData,
		intents = deps.intentStore,
		gateway = deps.gateway,
		sessionGuard = deps.sessionGuard,
		clock = deps.clock or os.time,
		ttl = deps.ttl or TransferConfig.IntentTtlSeconds,
		sourceRole = deps.sourceRole or "Lobby",
		onRecovery = deps.onRecovery,
		pending = {},
		teleportProtected = {},
		failureConnection = nil,
		removingConnection = nil,
		running = false,
	}, Service)
end

function Service:start(): ()
	if self.failureConnection ~= nil then
		return
	end
	self.running = true
	self.failureConnection = self.gateway:onInitFailed(function(player, reason, payload)
		if typeof(payload) ~= "table" or payload.transferId ~= self.pending[player] then
			return
		end
		self:recover(player, "TeleportInitFailed:" .. reason)
	end)
	self.removingConnection = Players.PlayerRemoving:Connect(function(player)
		-- A departing player means Roblox accepted the teleport. The destination
		-- still needs the intent, so source shutdown must no longer remove it.
		self:forget(player)
	end)
end

function Service:stop(): ()
	self.running = false
	if self.failureConnection ~= nil then
		self.failureConnection:Disconnect()
		self.failureConnection = nil
	end
	if self.removingConnection ~= nil then
		self.removingConnection:Disconnect()
		self.removingConnection = nil
	end

	-- Snapshot first: recover()/forget() mutate the pending table.
	local players = {}
	for player in self.pending do
		table.insert(players, player)
	end
	for _, player in players do
		if self.teleportProtected[player] then
			-- Once TeleportAsync has been entered, shutdown can no longer know
			-- whether Roblox accepted the handoff. Preserve the one-shot intent
			-- and released profile so a destination already starting can finish
			-- admission. If handoff ultimately fails, the intent expires and a
			-- later Lobby join can reclaim the released profile normally.
			self:forget(player)
		else
			self:recover(player, "ServiceStopping")
		end
	end
end

function Service:begin(player: Player, characterId: string, destination: any): (boolean, string?)
	if not self.running then
		return false, "ServiceNotRunning"
	end
	if self.pending[player] ~= nil then
		return false, "TransferInProgress"
	end
	if typeof(destination) ~= "table"
		or typeof(destination.placeId) ~= "number"
		or destination.placeId <= 0
		or typeof(destination.role) ~= "string"
		or typeof(destination.entryPointId) ~= "string"
	then
		return false, "InvalidDestination"
	end
	if self.data.getActiveCharacterId(player) ~= characterId then
		return false, "CharacterNotOwnedOrActive"
	end

	local transferId = HttpService:GenerateGUID(false)
	self.pending[player] = transferId

	local released, releaseReason = self.data.beginTransfer(player)
	if not released then
		self.pending[player] = nil
		return false, releaseReason
	end

	if self.pending[player] ~= transferId or not self.running or player.Parent ~= Players then
		if player.Parent == Players then
			self.data.recoverTransfer(player)
		end
		self.pending[player] = nil
		return false, "TransferCancelled"
	end

	local intent = {
		transferVersion = TransferConfig.Version,
		transferId = transferId,
		userId = player.UserId,
		characterId = characterId,
		sourceRole = self.sourceRole,
		destinationRole = destination.role,
		entryPointId = destination.entryPointId,
		expiresAt = self.clock() + self.ttl,
	}
	local made, makeReason = self.intents:create(intent, self.ttl)
	if not made then
		local recovered, recoveryReason = self.data.recoverTransfer(player)
		self.pending[player] = nil
		return false, if recovered then makeReason else recoveryReason
	end

	if self.pending[player] ~= transferId or not self.running or player.Parent ~= Players then
		local removed = self.intents:remove(transferId)
		if removed and player.Parent == Players then
			self.data.recoverTransfer(player)
		end
		self.pending[player] = nil
		return false, "TransferCancelled"
	end

	-- From this point shutdown must not eagerly reclaim/remove the handoff:
	-- TeleportAsync can yield after Roblox has accepted the destination.
	self.teleportProtected[player] = true
	local routingPayload = Rules.routingPayload(intent)
	if self.sessionGuard ~= nil then
		local guardedPayload, guardReason = self.sessionGuard.attachRoutingPayload(routingPayload, { player })
		if guardedPayload == nil then
			self.teleportProtected[player] = nil
			local removed, removeReason = self.intents:remove(transferId)
			if removed then
				self.data.recoverTransfer(player)
			else
				self.data.failSession(player, removeReason or "IntentCleanupFailed")
			end
			self.pending[player] = nil
			return false, guardReason or "SessionGuardRoutingFailed"
		end
		routingPayload = guardedPayload
		local handoffStarted, handoffReason = self.sessionGuard.beginHandoff({ player })
		if not handoffStarted then
			self.teleportProtected[player] = nil
			local removed, removeReason = self.intents:remove(transferId)
			if removed then
				self.data.recoverTransfer(player)
			else
				self.data.failSession(player, removeReason or "IntentCleanupFailed")
			end
			self.pending[player] = nil
			return false, handoffReason or "SessionGuardHandoffFailed"
		end
	end
	local sent, sendReason = self.gateway:teleport(destination.placeId, { player }, routingPayload)

	-- stop()/PlayerRemoving may have deliberately forgotten the source side
	-- while the TeleportAsync call yielded. In that case the intent must remain.
	if self.pending[player] ~= transferId or not self.running then
		return false, "TransferCancelled"
	end

	if not sent then
		self.teleportProtected[player] = nil
		local removed, removeReason = self.intents:remove(transferId)
		if removed then
			self.data.recoverTransfer(player)
		else
			self.data.failSession(player, removeReason or "IntentCleanupFailed")
		end
		self.pending[player] = nil
		return false, removeReason or sendReason
	end

	-- Keep teleportProtected set until PlayerRemoving, TeleportInitFailed or
	-- service shutdown resolves the source-side ownership ambiguity.
	return true, nil
end

function Service:recover(player: Player, _reason: string?): (boolean, string?)
	local transferId = self.pending[player]
	if transferId == nil then
		return false, "NoTransferInProgress"
	end
	self.teleportProtected[player] = nil
	if self.sessionGuard ~= nil then
		self.sessionGuard.cancelHandoff({ player })
	end

	local removed, removeReason = self.intents:remove(transferId)
	if not removed then
		self.data.failSession(player, removeReason or "IntentCleanupFailed")
		self.pending[player] = nil
		return false, removeReason
	end

	local ok, reason = self.data.recoverTransfer(player)
	self.pending[player] = nil
	if self.onRecovery ~= nil then
		self.onRecovery(player, if ok then (_reason or "TransferRecovered") else (reason or "TransferRecoveryFailed"))
	end
	return ok, reason
end

function Service:forget(player: Player): ()
	self.pending[player] = nil
	self.teleportProtected[player] = nil
end

return Service
