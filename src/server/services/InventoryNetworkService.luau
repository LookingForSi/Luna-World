--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Shared.config.InventoryConfig)
local InventoryRequestRules = require(ReplicatedStorage.Shared.inventory.InventoryRequestRules)
local InventoryService = require(script.Parent.InventoryService)
local WorldDropService = require(script.Parent.WorldDropService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local InventoryNetworkService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRequest = remotes:WaitForChild("InventoryActionRequest") :: RemoteEvent
local snapshotRequest = remotes:WaitForChild("InventorySnapshotRequest") :: RemoteEvent
local snapshotEvent = remotes:WaitForChild("InventorySnapshot") :: RemoteEvent
local actionResult = remotes:WaitForChild("InventoryActionResult") :: RemoteEvent

local started = false
local connections: { RBXScriptConnection } = {}
local lastActionRequestAt: { [Player]: number } = {}
local lastSnapshotRequestAt: { [Player]: number } = {}

local function rateLimited(now: number, previous: number?, interval: number): boolean
	return previous ~= nil and now - previous < interval
end

local function pushSnapshot(player: Player): ()
	if player.Parent ~= Players or not PlayerDataService.isReady(player) then return end
	local snapshot = InventoryService.createClientSnapshot(player)
	if snapshot ~= nil then snapshotEvent:FireClient(player, snapshot) end
end

local function onSnapshotRequest(player: Player, ...: unknown): ()
	if not InventoryRequestRules.validateSnapshotRequest(select("#", ...)) then return end
	local now = workspace:GetServerTimeNow()
	if rateLimited(now, lastSnapshotRequestAt[player], InventoryConfig.SnapshotRequestMinIntervalSeconds) then return end
	lastSnapshotRequestAt[player] = now
	pushSnapshot(player)
end

local function onActionRequest(player: Player, ...: unknown): ()
	local action, identifier = InventoryRequestRules.validateAction(
		select("#", ...),
		select(1, ...),
		select(2, ...)
	)
	if action == nil or identifier == nil then return end

	local now = workspace:GetServerTimeNow()
	if rateLimited(now, lastActionRequestAt[player], InventoryConfig.ActionRequestMinIntervalSeconds) then
		return
	end
	lastActionRequestAt[player] = now
	if not PlayerDataService.isReady(player) then return end

	local ok = false
	local reason: string? = nil
	if action == "Equip" then
		ok, reason = InventoryService.equip(player, identifier)
	elseif action == "Unequip" then
		ok, reason = InventoryService.unequip(player, identifier)
	elseif action == "Consume" then
		ok, reason = InventoryService.consume(player, identifier)
	elseif action == "Discard" then
		local itemId: string? = nil
		local quantity: number? = nil
		ok, reason, itemId, quantity = InventoryService.discard(player, identifier)
		if ok and itemId ~= nil and quantity ~= nil then
			WorldDropService.spawnForPlayer(player, itemId, quantity)
		end
	end

	actionResult:FireClient(player, {
		action = action,
		identifier = identifier,
		ok = ok,
		reason = reason,
	})
end

function InventoryNetworkService.start(): ()
	if started then return end
	started = true
	table.insert(connections, snapshotRequest.OnServerEvent:Connect(onSnapshotRequest))
	table.insert(connections, actionRequest.OnServerEvent:Connect(onActionRequest))
	table.insert(connections, PlayerDataService.ProfileReady:Connect(pushSnapshot))
	table.insert(connections, PlayerDataService.ProfileChanged:Connect(pushSnapshot))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		lastActionRequestAt[player] = nil
		lastSnapshotRequestAt[player] = nil
	end))
end

function InventoryNetworkService.stop(): ()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	table.clear(lastActionRequestAt)
	table.clear(lastSnapshotRequestAt)
end

return InventoryNetworkService
