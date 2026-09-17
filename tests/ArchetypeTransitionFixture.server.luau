--!strict

-- Test-project-only bridge for the runtime contract's archetype swaps.
-- CombatService owns the replicated archetype attribute, so changing that attribute
-- while an old combat snapshot still exists is intentionally overwritten by cleanup.
-- The runtime contract needs a deterministic server-side transition between archetypes;
-- clear the old authoritative snapshot first, then restore the requested archetype so
-- the immediately following LoadCharacter() initializes the new snapshot from it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatService = require(ServerScriptService.Server.services.CombatService)

local transitioning: { [Player]: boolean } = {}
local connections: { [Player]: RBXScriptConnection } = {}

local function onArchetypeChanged(player: Player): ()
	if transitioning[player] then return end
	local requested = player:GetAttribute(CombatConfig.ArchetypeAttribute)
	if requested ~= "ranger" and requested ~= "mystic" then return end

	transitioning[player] = true
	CombatService.handlePlayerDeath(player)
	player:SetAttribute(CombatConfig.ArchetypeAttribute, requested)
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
