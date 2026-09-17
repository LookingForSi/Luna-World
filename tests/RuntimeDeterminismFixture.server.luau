--!strict

-- Test-project-only timing fixture. It keeps lifecycle integration checks deterministic
-- without changing production combat/respawn tuning.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatService = require(ServerScriptService.Server.services.CombatService)

local FAST_TEST_RESPAWN_SECONDS = 1

local resourceHeldEmpty: { [Player]: boolean } = {}
local resourceConnections: { [Player]: RBXScriptConnection } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}

local function disconnectDeath(player: Player): ()
	local connection = deathConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		deathConnections[player] = nil
	end
end

local function bindCharacter(player: Player, character: Model): ()
	disconnectDeath(player)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then return end

	deathConnections[player] = humanoid.Died:Connect(function()
		local deadCharacter = character
		task.delay(FAST_TEST_RESPAWN_SECONDS, function()
			if player.Parent ~= Players or player.Character ~= deadCharacter then return end
			local currentHumanoid = deadCharacter:FindFirstChildOfClass("Humanoid")
			if currentHumanoid == nil or currentHumanoid.Health > 0 then return end
			-- RespawnService has already captured the settlement anchor and pending generation.
			-- Loading early only shortens the test wait; its CharacterAdded handler still owns
			-- placement, combat reset and stale delayed-respawn invalidation.
			player:LoadCharacter()
		end)
	end)
end

local function updateResourceHold(player: Player): ()
	local current = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
	local maximum = player:GetAttribute(CombatConfig.ResourceMaximumAttribute)
	if typeof(current) ~= "number" then return end

	if current == 0 then
		resourceHeldEmpty[player] = true
	elseif resourceHeldEmpty[player] and typeof(maximum) == "number" and current >= maximum then
		-- The runtime fixture explicitly restores the resource with SetResourceFull.
		resourceHeldEmpty[player] = nil
	end
end

local function addPlayer(player: Player): ()
	if resourceConnections[player] ~= nil then return end
	resourceConnections[player] = player:GetAttributeChangedSignal(CombatConfig.ResourceCurrentAttribute):Connect(function()
		updateResourceHold(player)
	end)
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end)
	if player.Character ~= nil then bindCharacter(player, player.Character) end
	updateResourceHold(player)
end

local function removePlayer(player: Player): ()
	resourceHeldEmpty[player] = nil
	disconnectDeath(player)
	local resourceConnection = resourceConnections[player]
	if resourceConnection ~= nil then resourceConnection:Disconnect() end
	resourceConnections[player] = nil
	local characterConnection = characterConnections[player]
	if characterConnection ~= nil then characterConnection:Disconnect() end
	characterConnections[player] = nil
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)
for _, player in Players:GetPlayers() do addPlayer(player) end

RunService.Heartbeat:Connect(function()
	for player in resourceHeldEmpty do
		if player.Parent ~= Players then
			resourceHeldEmpty[player] = nil
			continue
		end
		local current = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
		local maximum = player:GetAttribute(CombatConfig.ResourceMaximumAttribute)
		if typeof(current) ~= "number" or typeof(maximum) ~= "number" then continue end
		if current >= maximum then
			resourceHeldEmpty[player] = nil
		elseif current > 0 then
			-- SetResourceEmpty is testing insufficient-resource rejection, not regeneration.
			-- Hold the authoritative test seam at zero until SetResourceFull restores max.
			CombatService._setResourceForTest(player, 0)
		end
	end
end)
