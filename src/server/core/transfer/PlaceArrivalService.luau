--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.core.transfer.TransferIntentRules)

local Service = {}
Service.__index = Service

function Service.new(deps: any): any
	return setmetatable({
		data = deps.playerData,
		intents = deps.intentStore,
		destinationRole = deps.destinationRole,
		clock = deps.clock or os.time,
		connections = {},
		processing = {},
	}, Service)
end

function Service:admit(player: Player): (boolean, string?)
	local payload = player:GetJoinData().TeleportData
	return Rules.validateRouting(payload, self.destinationRole)
end

function Service:_arrive(player: Player): ()
	if self.processing[player] then
		return
	end
	self.processing[player] = true
	local joinData = player:GetJoinData()
	local payload = joinData.TeleportData
	local valid, reason = Rules.validateRouting(payload, self.destinationRole)
	if not valid then
		self.data:failSession(player, reason or "InvalidTransferPayload")
		self.processing[player] = nil
		return
	end
	local intent, consumeReason = self.intents:consume(payload.transferId)
	if intent == nil then
		self.data:failSession(player, consumeReason or "InvalidTransferIntent")
		self.processing[player] = nil
		return
	end
	local intentValid, intentReason = Rules.validate(intent, self.clock(), self.destinationRole)
	if not intentValid or intent.userId ~= player.UserId or intent.characterId ~= payload.characterId then
		self.data:failSession(player, intentReason or "TransferOwnershipMismatch")
		self.processing[player] = nil
		return
	end
	local selected, selectReason = self.data:selectCharacter(player, intent.characterId)
	if not selected then
		self.data:failSession(player, selectReason or "CharacterActivationFailed")
	end
	self.processing[player] = nil
end

function Service:start(): ()
	table.insert(self.connections, self.data.AccountReady:Connect(function(player)
		self:_arrive(player)
	end))
	for _, player in Players:GetPlayers() do
		if self.data:isAccountReady(player) then
			task.spawn(function() self:_arrive(player) end)
		end
	end
end

function Service:stop(): ()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	table.clear(self.processing)
end

return Service
