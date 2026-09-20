--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage.Shared.config.EconomyConfig)
local EconomyRequestRules = require(ReplicatedStorage.Shared.economy.EconomyRequestRules)
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EconomyNetworkService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("EconomyRequest") :: RemoteEvent
local snapshot = remotes:WaitForChild("EconomySnapshot") :: RemoteEvent
local openEvent = remotes:WaitForChild("EconomyOpen") :: RemoteEvent
local resultEvent = remotes:WaitForChild("EconomyResult") :: RemoteEvent
local started = false
local connections: { RBXScriptConnection } = {}
local lastAt: { [Player]: number } = {}

local function poiPosition(id: string): Vector3?
	for _, poi in WorldLayout.PointsOfInterest do if poi.id == id then return poi.position end end
	return nil
end
local function interactionPosition(poiId: string): Vector3?
	local npcName = if poiId == EconomyConfig.BlacksmithPoiId then "BlacksmithNpc" else "MerchantNpc"
	local world = workspace:FindFirstChild("LunaWorldPlayableBlockout")
	local npc = if world ~= nil then world:FindFirstChild(npcName, true) else nil
	if npc ~= nil and npc:IsA("Model") then
		local body = npc:FindFirstChild("Body") or npc:FindFirstChild("Head")
		if body ~= nil and body:IsA("BasePart") then return body.Position end
	end
	return poiPosition(poiId)
end

local function nearby(player: Player, poiId: string): boolean
	local root = if player.Character ~= nil then player.Character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if player.Character ~= nil then player.Character:FindFirstChildOfClass("Humanoid") else nil
	local position = interactionPosition(poiId)
	return root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0 and position ~= nil and (root.Position - position).Magnitude <= EconomyConfig.InteractionDistance
end
local function push(player: Player): ()
	local value = EconomyService.createSnapshot(player); if value ~= nil then snapshot:FireClient(player, value) end
end

local function onRequest(player: Player, ...: unknown): ()
	local action, identifier, quantity = EconomyRequestRules.validate(select("#", ...), select(1, ...), select(2, ...), select(3, ...))
	if action == nil or identifier == nil or quantity == nil then return end
	local now = workspace:GetServerTimeNow(); if lastAt[player] ~= nil and now - lastAt[player] < EconomyConfig.RequestMinIntervalSeconds then return end
	lastAt[player] = now
	if not PlayerDataService.isReady(player) then return end
	local poiId = if action == "Craft" then EconomyConfig.BlacksmithPoiId else EconomyConfig.MerchantPoiId
	if not nearby(player, poiId) then resultEvent:FireClient(player, { action = action, ok = false, reason = "TooFar" }); return end
	local ok = false
	local reason: string? = nil
	if action == "Buy" then
		ok, reason = EconomyService.buy(player, identifier, quantity)
	elseif action == "Sell" then
		ok, reason = EconomyService.sell(player, identifier, quantity)
	else
		ok, reason = EconomyService.craft(player, identifier)
	end
	resultEvent:FireClient(player, { action = action, identifier = identifier, ok = ok, reason = reason })
	if ok then push(player) end
end

function EconomyNetworkService.openFor(player: Player, mode: string): ()
	local poiId = if mode == "Craft" then EconomyConfig.BlacksmithPoiId else EconomyConfig.MerchantPoiId
	if mode ~= "Craft" and mode ~= "Merchant" then return end
	if nearby(player, poiId) and PlayerDataService.isReady(player) then
		push(player)
		openEvent:FireClient(player, if mode == "Craft" then "DialogueBlacksmith" else "DialogueMerchant")
	end
end
function EconomyNetworkService.start(): ()
	if started then return end; started = true
	table.insert(connections, request.OnServerEvent:Connect(onRequest))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player) lastAt[player] = nil end))
end
function EconomyNetworkService.stop(): ()
	if not started then return end; started = false
	for _, connection in connections do connection:Disconnect() end; table.clear(connections); table.clear(lastAt)
end
return EconomyNetworkService
