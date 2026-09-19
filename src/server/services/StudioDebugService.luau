--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatService = require(script.Parent.CombatService)
local InventoryService = require(script.Parent.InventoryService)
local ProgressionService = require(script.Parent.ProgressionService)

local StudioDebugService = {}

local archetypeRemote: RemoteEvent? = nil
local levelRemote: RemoteEvent? = nil
local testItemsRemote: RemoteEvent? = nil
local archetypeConnection: RBXScriptConnection? = nil
local levelConnection: RBXScriptConnection? = nil
local testItemsConnection: RBXScriptConnection? = nil
local started = false

local function createRemote(name: string): RemoteEvent
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild(name)
	if existing ~= nil and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = remotes
	return created
end

function StudioDebugService.start(): ()
	if started or not RunService:IsStudio() then return end
	started = true
	archetypeRemote = createRemote("StudioSetArchetype")
	levelRemote = createRemote("StudioSetLevel")
	testItemsRemote = createRemote("StudioGrantTestItems")
	archetypeConnection = (archetypeRemote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, archetypeId: unknown, ...)
		if select("#", ...) ~= 0 or typeof(archetypeId) ~= "string" then return end
		CombatService._setArchetypeForStudio(player, archetypeId)
	end)
	levelConnection = (levelRemote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, level: unknown, ...)
		if select("#", ...) ~= 0 or typeof(level) ~= "number" then return end
		ProgressionService._setLevelForStudio(player, level)
	end)
	testItemsConnection = (testItemsRemote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then return end
		for _, grant in {
			{ "weapon_training_sword", 1 },
			{ "weapon_ash_bow", 1 },
			{ "weapon_ash_staff", 1 },
			{ "armor_worn_chest", 1 },
			{ "consumable_minor_healing_draught", 3 },
			{ "consumable_minor_resource_draught", 3 },
		} do
			InventoryService.grantItem(player, grant[1] :: string, grant[2] :: number)
		end
	end)
end

function StudioDebugService.stop(): ()
	if not started then return end
	started = false
	if archetypeConnection ~= nil then archetypeConnection:Disconnect(); archetypeConnection = nil end
	if levelConnection ~= nil then levelConnection:Disconnect(); levelConnection = nil end
	if testItemsConnection ~= nil then testItemsConnection:Disconnect(); testItemsConnection = nil end
	if archetypeRemote ~= nil then archetypeRemote:Destroy(); archetypeRemote = nil end
	if levelRemote ~= nil then levelRemote:Destroy(); levelRemote = nil end
	if testItemsRemote ~= nil then testItemsRemote:Destroy(); testItemsRemote = nil end
end

return StudioDebugService
