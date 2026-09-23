--!strict

-- Test-project-only bridge for the runtime contract's archetype swaps.
-- CombatCoordinator owns the replicated archetype attribute, so changing that attribute
-- while an old combat snapshot still exists is overwritten by cleanup. The runtime
-- contract deliberately swaps archetypes in one Studio session, so make that server-
-- authoritative transition deterministic without changing production gameplay APIs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatCoordinator = require(ServerScriptService.Server.features.combat.CombatCoordinator)

local transitioning: { [Player]: boolean } = {}
local connections: { [Player]: RBXScriptConnection } = {}

local function onArchetypeChanged(player: Player): ()
	if transitioning[player] then return end
	local requested = player:GetAttribute(CombatConfig.ArchetypeAttribute)
	if requested ~= "ranger" and requested ~= "mystic" then return end

	transitioning[player] = true
	local character = player.Character

	-- Clear the old authoritative snapshot before restoring the requested archetype.
	-- Re-initialize the current character as well: the attribute signal may run either
	-- just before or just after the runtime contract's immediately following LoadCharacter().
	CombatCoordinator.handlePlayerDeath(player)
	player:SetAttribute(CombatConfig.ArchetypeAttribute, requested)
	if character ~= nil and player.Character == character then
		CombatCoordinator.handlePlayerRespawn(player, character)
	end

	transitioning[player] = nil
end

local function addPlayer(player: Player): ()
	if connections[player] ~= nil then return end
	connections[player] = player:GetAttributeChangedSignal(CombatConfig.ArchetypeAttribute):Connect(function()
		onArchetypeChanged(player)
	end)
end

local function removePlayer(player: Player): ()
	transitioning[player] = nil
	local connection = connections[player]
	if connection ~= nil then connection:Disconnect() end
	connections[player] = nil
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)
for _, player in Players:GetPlayers() do addPlayer(player) end
