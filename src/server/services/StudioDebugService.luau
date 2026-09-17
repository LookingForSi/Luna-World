--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)

local StudioDebugService = {}

local remote: RemoteEvent? = nil
local connection: RBXScriptConnection? = nil
local started = false

local function createRemote(): RemoteEvent
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild("StudioSetArchetype")
	if existing ~= nil and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "StudioSetArchetype"
	created.Parent = remotes
	return created
end

function StudioDebugService.start(): ()
	if started or not RunService:IsStudio() then return end
	started = true
	remote = createRemote()
	connection = (remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, archetypeId: unknown, ...)
		if select("#", ...) ~= 0 then return end
		if typeof(archetypeId) ~= "string" or ArchetypeDefinitions[archetypeId] == nil then return end
		player:SetAttribute(CombatConfig.ArchetypeAttribute, archetypeId)
		-- A fresh character lets the existing authoritative respawn/combat lifecycle rebuild
		-- stats, resources, cooldown state and UI-facing attributes from the new archetype.
		player:LoadCharacter()
	end)
end

function StudioDebugService.stop(): ()
	if not started then return end
	started = false
	if connection ~= nil then connection:Disconnect(); connection = nil end
	if remote ~= nil then remote:Destroy(); remote = nil end
end

return StudioDebugService
