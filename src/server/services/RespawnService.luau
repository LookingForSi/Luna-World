--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RespawnRules = require(ReplicatedStorage.Shared.combat.RespawnRules)
local RespawnConfig = require(ReplicatedStorage.Shared.config.RespawnConfig)
local CombatService = require(script.Parent.CombatService)

type PlayerRecord = {
	generation: number,
	pending: boolean,
	anchor: BasePart?,
	characterConnection: RBXScriptConnection?,
	deathConnection: RBXScriptConnection?,
}

local RespawnService = {}
local anchors: { [BasePart]: boolean } = {}
local records: { [Player]: PlayerRecord } = {}
local serviceConnections: { RBXScriptConnection } = {}
local started = false
local previousCharacterAutoLoads = true

local function anchorId(anchor: BasePart): string
	local configured = anchor:GetAttribute(RespawnConfig.AnchorIdAttribute)
	return if typeof(configured) == "string" and configured ~= "" then configured else anchor:GetFullName()
end

local function registerAnchor(instance: Instance): ()
	if instance:IsA("BasePart") then anchors[instance] = true end
end

local function unregisterAnchor(instance: Instance): ()
	if instance:IsA("BasePart") then anchors[instance] = nil end
end

local function nearestAnchor(origin: Vector3): BasePart?
	local candidates: { RespawnRules.AnchorCandidate } = {}
	local byId: { [string]: BasePart } = {}
	for anchor in anchors do
		if anchor.Parent ~= nil then
			local settlementId = anchor:GetAttribute(RespawnConfig.SettlementIdAttribute)
			if typeof(settlementId) == "string" and settlementId ~= "" then
				local id = anchorId(anchor)
				table.insert(candidates, { id = id, position = anchor.Position, settlementId = settlementId })
				byId[id] = anchor
			end
		end
	end
	local selectedId = RespawnRules.nearestAnchorId(origin, candidates)
	return if selectedId ~= nil then byId[selectedId] else nil
end

local function disconnectDeath(record: PlayerRecord): ()
	if record.deathConnection ~= nil then record.deathConnection:Disconnect() end
	record.deathConnection = nil
end

local function onDied(player: Player, character: Model, deathPosition: Vector3): ()
	local record = records[player]
	if record == nil or player.Character ~= character then return end
	local accepted, generation = RespawnRules.beginDeath(record.pending, record.generation)
	if not accepted then return end
	record.pending = true
	record.generation = generation
	record.anchor = nearestAnchor(deathPosition)
	CombatService.handlePlayerDeath(player)
	if record.anchor == nil then
		record.pending = false
		warn(string.format("Respawn blocked for %s: no registered settlement RespawnAnchor", player.Name))
		return
	end
	task.delay(RespawnConfig.RespawnDelaySeconds, function()
		local current = records[player]
		if current ~= record or not RespawnRules.isCurrentGeneration(generation, record.generation) or not record.pending then return end
		if player.Parent ~= Players then return end
		player:LoadCharacter()
	end)
end

local function bindCharacter(player: Player, character: Model): ()
	local record = records[player]
	if record == nil then return end
	disconnectDeath(record)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
	if player.Character ~= character or humanoid == nil or not humanoid:IsA("Humanoid") then return end
	if root ~= nil and root:IsA("BasePart") and record.pending and record.anchor ~= nil and record.anchor.Parent ~= nil then
		character:PivotTo(RespawnRules.spawnCFrame(record.anchor.CFrame, humanoid.HipHeight, root.Size.Y))
	end
	record.pending = false
	record.anchor = nil
	CombatService.handlePlayerRespawn(player, character)
	record.deathConnection = humanoid.Died:Connect(function()
		local currentRoot = character:FindFirstChild("HumanoidRootPart")
		local position = if currentRoot ~= nil and currentRoot:IsA("BasePart") then currentRoot.Position else character:GetPivot().Position
		onDied(player, character, position)
	end)
end

local function addPlayer(player: Player): ()
	if records[player] ~= nil then return end
	local record: PlayerRecord = { generation = 0, pending = false, anchor = nil, characterConnection = nil, deathConnection = nil }
	records[player] = record
	record.characterConnection = player.CharacterAdded:Connect(function(character) bindCharacter(player, character) end)
	if player.Character ~= nil then
		bindCharacter(player, player.Character)
	else
		player:LoadCharacter()
	end
end

local function removePlayer(player: Player): ()
	local record = records[player]
	if record == nil then return end
	record.generation += 1
	disconnectDeath(record)
	if record.characterConnection ~= nil then record.characterConnection:Disconnect() end
	records[player] = nil
end

function RespawnService.start(): ()
	if started then return end
	started = true
	previousCharacterAutoLoads = Players.CharacterAutoLoads
	Players.CharacterAutoLoads = false
	-- Subscribe before enumeration so an anchor added during startup cannot fall between
	-- the initial snapshot and signal registration.
	table.insert(serviceConnections, CollectionService:GetInstanceAddedSignal(RespawnConfig.AnchorTag):Connect(registerAnchor))
	table.insert(serviceConnections, CollectionService:GetInstanceRemovedSignal(RespawnConfig.AnchorTag):Connect(unregisterAnchor))
	for _, instance in CollectionService:GetTagged(RespawnConfig.AnchorTag) do registerAnchor(instance) end
	local hasLunaVillageAnchor = false
	for anchor in anchors do
		if anchor:GetAttribute(RespawnConfig.SettlementIdAttribute) == RespawnConfig.LunaVillageSettlementId then
			hasLunaVillageAnchor = true
			break
		end
	end
	if not hasLunaVillageAnchor then
		-- The world branch supplies this tagged interface. Combat does not invent a coordinate fallback.
		warn("Luna Village RespawnAnchor is not registered; deaths remain safely unrespawned until the world provides it")
	end
	table.insert(serviceConnections, Players.PlayerAdded:Connect(addPlayer))
	table.insert(serviceConnections, Players.PlayerRemoving:Connect(removePlayer))
	for _, player in Players:GetPlayers() do addPlayer(player) end
end

function RespawnService.stop(): ()
	if not started then return end
	started = false
	for _, connection in serviceConnections do connection:Disconnect() end
	table.clear(serviceConnections)
	local players = {}
	for player in records do table.insert(players, player) end
	for _, player in players do removePlayer(player) end
	table.clear(anchors)
	Players.CharacterAutoLoads = previousCharacterAutoLoads
end

return RespawnService
