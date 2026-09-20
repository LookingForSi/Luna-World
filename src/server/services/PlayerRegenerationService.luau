--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)

local PlayerRegenerationService = {}

type Record = {
	character: Model,
	humanoid: Humanoid,
	lastHealth: number,
	lastDamageAt: number,
	healthConnection: RBXScriptConnection,
	childConnection: RBXScriptConnection,
}

local records: { [Player]: Record } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local serviceConnections: { RBXScriptConnection } = {}
local heartbeatConnection: RBXScriptConnection? = nil
local accumulated = 0
local started = false

local function suppressStockHealthScript(instance: Instance): ()
	if instance.Name == "Health" and instance:IsA("Script") then
		instance:Destroy()
	end
end

local function clearRecord(player: Player): ()
	local record = records[player]
	if record == nil then return end
	record.healthConnection:Disconnect()
	record.childConnection:Disconnect()
	records[player] = nil
end

local function registerCharacter(player: Player, character: Model): ()
	clearRecord(player)

	for _, child in character:GetChildren() do
		suppressStockHealthScript(child)
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		local candidate = character:WaitForChild("Humanoid", 10)
		if candidate == nil or not candidate:IsA("Humanoid") or player.Character ~= character then return end
		humanoid = candidate
	end

	local now = workspace:GetServerTimeNow()
	local record = {} :: Record
	record.character = character
	record.humanoid = humanoid
	record.lastHealth = humanoid.Health
	record.lastDamageAt = now
	record.healthConnection = humanoid.HealthChanged:Connect(function(health: number)
		if records[player] ~= record then return end
		if health < record.lastHealth - 0.001 then
			record.lastDamageAt = workspace:GetServerTimeNow()
		end
		record.lastHealth = health
	end)
	record.childConnection = character.ChildAdded:Connect(suppressStockHealthScript)
	records[player] = record
end

local function addPlayer(player: Player): ()
	if characterConnections[player] ~= nil then return end
	characterConnections[player] = player.CharacterAdded:Connect(function(character: Model)
		registerCharacter(player, character)
	end)
	if player.Character ~= nil then
		task.defer(registerCharacter, player, player.Character)
	end
end

local function removePlayer(player: Player): ()
	clearRecord(player)
	local connection = characterConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		characterConnections[player] = nil
	end
end

function PlayerRegenerationService.start(): ()
	if started then return end
	started = true
	accumulated = 0

	table.insert(serviceConnections, Players.PlayerAdded:Connect(addPlayer))
	table.insert(serviceConnections, Players.PlayerRemoving:Connect(removePlayer))
	for _, player in Players:GetPlayers() do addPlayer(player) end

	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaSeconds: number)
		accumulated += deltaSeconds
		if accumulated < CombatConfig.HealthRegenerationIntervalSeconds then return end
		local elapsed = accumulated
		accumulated = 0
		local now = workspace:GetServerTimeNow()

		for player, record in records do
			local humanoid = record.humanoid
			if player.Parent ~= Players
				or player.Character ~= record.character
				or record.character.Parent == nil
				or humanoid.Parent == nil
				or humanoid.Health <= 0
			then
				continue
			end
			if humanoid.Health >= humanoid.MaxHealth then continue end
			if now - record.lastDamageAt < CombatConfig.HealthRegenerationDelaySeconds then continue end

			local restore = humanoid.MaxHealth
				* CombatConfig.HealthRegenerationFractionPerSecond
				* elapsed
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + restore)
			record.lastHealth = humanoid.Health
		end
	end)
end

function PlayerRegenerationService.stop(): ()
	if not started then return end
	started = false
	if heartbeatConnection ~= nil then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
	for _, connection in serviceConnections do connection:Disconnect() end
	table.clear(serviceConnections)

	local players = {}
	for player in records do table.insert(players, player) end
	for _, player in players do clearRecord(player) end
	for player, connection in characterConnections do
		connection:Disconnect()
		characterConnections[player] = nil
	end
	accumulated = 0
end

return PlayerRegenerationService
