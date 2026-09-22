--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.core.transfer.TransferIntentRules)

local Service = {}
Service.__index = Service

function Service.new(deps: any): any
	return setmetatable({
		data = deps.playerData,
		intents = deps.intentStore,
		gateway = deps.gateway,
		clock = deps.clock or os.time,
		ttl = deps.ttl or 60,
		pending = {},
		failureConnection = nil,
		removingConnection = nil,
	}, Service)
end

function Service:start(): ()
	if self.failureConnection ~= nil then
		return
	end
	self.failureConnection = self.gateway:onInitFailed(function(player, reason)
		self:recover(player, "TeleportInitFailed:" .. reason)
	end)
	self.removingConnection = Players.PlayerRemoving:Connect(function(player)
		-- A departing player means Roblox accepted the teleport. The destination
		-- still needs the intent, so source shutdown must no longer remove it.
		self:forget(player)
	end)
end

function Service:stop(): ()
	if self.failureConnection ~= nil then
		self.failureConnection:Disconnect()
		self.failureConnection = nil
	end
	if self.removingConnection ~= nil then
		self.removingConnection:Disconnect()
		self.removingConnection = nil
	end
	for player in self.pending do
		self:recover(player, "ServiceStopping")
	end
end

function Service:begin(player: Player, characterId: string, destination: any): (boolean, string?)
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
	if self.data:getActiveCharacterId(player) ~= characterId then
		return false, "CharacterNotOwnedOrActive"
	end

	local transferId = HttpService:GenerateGUID(false)
	self.pending[player] = transferId
	local released, releaseReason = self.data:beginTransfer(player)
	if not released then
		self.pending[player] = nil
		return false, releaseReason
	end
	local intent = {
		transferVersion = 1,
		transferId = transferId,
		userId = player.UserId,
		characterId = characterId,
		destinationRole = destination.role,
		entryPointId = destination.entryPointId,
		expiresAt = self.clock() + self.ttl,
	}
	local made, makeReason = self.intents:create(intent, self.ttl)
	if not made then
		self.data:recoverTransfer(player)
		self.pending[player] = nil
		return false, makeReason
	end
	local sent, sendReason = self.gateway:teleport(destination.placeId, { player }, Rules.routingPayload(intent))
	if not sent then
		local removed, removeReason = self.intents:remove(transferId)
		if removed then
			self.data:recoverTransfer(player)
		else
			self.data:failSession(player, removeReason or "IntentCleanupFailed")
		end
		self.pending[player] = nil
		return false, removeReason or sendReason
	end
	if self.pending[player] ~= transferId then
		return false, "TeleportInitFailed"
	end
	return true, nil
end

function Service:recover(player: Player, _reason: string?): (boolean, string?)
	local transferId = self.pending[player]
	if transferId == nil then
		return false, "NoTransferInProgress"
	end
	local removed, removeReason = self.intents:remove(transferId)
	if not removed then
		self.data:failSession(player, removeReason or "IntentCleanupFailed")
		self.pending[player] = nil
		return false, removeReason
	end
	local ok, reason = self.data:recoverTransfer(player)
	self.pending[player] = nil
	return ok, reason
end

function Service:forget(player: Player): ()
	self.pending[player] = nil
end

return Service
