--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NpcDefinitions = require(ReplicatedStorage.Shared.definitions.NpcDefinitions)
local TravelDefinitions = require(ReplicatedStorage.Shared.definitions.TravelDefinitions)
local TravelRules = require(ReplicatedStorage.Shared.travel.TravelRules)
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TravelService = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestEvent = remotes:WaitForChild("TravelRequest") :: RemoteEvent
local resultEvent = remotes:WaitForChild("TravelResult") :: RemoteEvent

local connections: { RBXScriptConnection } = {}
local lastRequestAt: { [Player]: number } = {}
local started = false

local function poiPosition(id: string): Vector3?
	for _, value in WorldLayout.PointsOfInterest do
		if value.id == id then return value.position end
	end
	return nil
end

local function npcPosition(npcId: string): Vector3?
	local definition = NpcDefinitions[npcId]
	if definition == nil then return nil end

	local world = workspace:FindFirstChild("LunaWorldPlayableBlockout")
	local model = if world ~= nil then world:FindFirstChild(definition.modelName, true) else nil
	if model ~= nil and model:IsA("Model") then
		return model:GetPivot().Position
	end

	local base = poiPosition(definition.poiId)
	return if base ~= nil then base + (definition.positionOffset or Vector3.zero) else nil
end

local function livingCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function nearNpc(player: Player, npcId: string): boolean
	local _, _, root = livingCharacter(player)
	local position = npcPosition(npcId)
	return root ~= nil and position ~= nil and (root.Position - position).Magnitude <= 18
end

local function validId(value: unknown): boolean
	return typeof(value) == "string" and #value > 0 and #value <= 64
end

local function fail(player: Player, travelId: unknown, reason: string): ()
	resultEvent:FireClient(player, { ok = false, travelId = travelId, reason = reason })
end

local function handleRequest(player: Player, ...: unknown): ()
	if select("#", ...) ~= 2 then return end
	local travelId, sourceNpcId = select(1, ...), select(2, ...)
	if not validId(travelId) or not validId(sourceNpcId) then return end

	local now = workspace:GetServerTimeNow()
	local previous = lastRequestAt[player]
	if previous ~= nil and now - previous < 0.35 then return end
	lastRequestAt[player] = now

	local definition = TravelDefinitions[travelId :: string]
	if definition == nil or NpcDefinitions[sourceNpcId :: string] == nil then return end

	local destinationNpcId = TravelRules.destinationNpcId(definition, sourceNpcId :: string)
	if destinationNpcId == nil then
		fail(player, travelId, "InvalidEndpoint")
		return
	end
	if not PlayerDataService.isReady(player) then
		fail(player, travelId, "ProfileNotReady")
		return
	end
	if not nearNpc(player, sourceNpcId :: string) then
		fail(player, travelId, "TooFar")
		return
	end

	local profile = PlayerDataService.getProfileCopy(player)
	if profile == nil or not TravelRules.isUnlocked(profile.Quests, definition) then
		fail(player, travelId, "Locked")
		return
	end

	local destinationPosition = npcPosition(destinationNpcId)
	if destinationPosition == nil then
		fail(player, travelId, "DestinationUnavailable")
		return
	end
	local character, _, root = livingCharacter(player)
	if character == nil or root == nil then
		fail(player, travelId, "CharacterUnavailable")
		return
	end

	local cost = TravelRules.costLuna(definition)
	local charged = false
	local mutationReason: string? = nil
	local mutated, reason = PlayerDataService.mutate(player, function(value)
		if not TravelRules.isUnlocked(value.Quests, definition) then
			mutationReason = "Locked"
			return
		end
		if value.Luna < cost then
			mutationReason = "InsufficientLuna"
			return
		end
		value.Luna -= cost
		charged = true
	end)
	if not mutated then
		fail(player, travelId, reason or "MutationFailed")
		return
	end
	if not charged then
		fail(player, travelId, mutationReason or "Rejected")
		return
	end

	local arrival = destinationPosition + TravelRules.arrivalOffset(definition, destinationNpcId)
	local moved = pcall(function()
		character:PivotTo(CFrame.new(arrival))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
	if not moved then
		-- Travel must not consume currency if the world cannot complete the move.
		PlayerDataService.mutate(player, function(value)
			value.Luna += cost
		end)
		fail(player, travelId, "TeleportFailed")
		return
	end

	resultEvent:FireClient(player, {
		ok = true,
		travelId = travelId,
		sourceNpcId = sourceNpcId,
		destinationNpcId = destinationNpcId,
		costLuna = cost,
	})
end

function TravelService.start(): ()
	if started then return end
	started = true
	table.insert(connections, requestEvent.OnServerEvent:Connect(handleRequest))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end))
end

function TravelService.stop(): ()
	if not started then return end
	started = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	table.clear(lastRequestAt)
end

return TravelService
