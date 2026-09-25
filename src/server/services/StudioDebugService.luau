--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatCoordinator = require(script.Parent.Parent.features.combat.CombatCoordinator)
local EconomyService = require(script.Parent.EconomyService)
local ProgressionService = require(script.Parent.ProgressionService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local QuestDefinitions = require(ReplicatedStorage.Shared.definitions.QuestDefinitions)
local DungeonUnlockRules = require(ReplicatedStorage.Shared.dungeon.DungeonUnlockRules)

local StudioDebugService = {}

local archetypeRemote: RemoteEvent? = nil
local levelRemote: RemoteEvent? = nil
local unlockRuinsRemote: RemoteEvent? = nil
local speedRemote: RemoteEvent? = nil
local archetypeConnection: RBXScriptConnection? = nil
local levelConnection: RBXScriptConnection? = nil
local unlockRuinsConnection: RBXScriptConnection? = nil
local speedConnection: RBXScriptConnection? = nil
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
	unlockRuinsRemote = createRemote("StudioUnlockRuins")
	speedRemote = createRemote("StudioToggleSpeed")
	archetypeConnection = (archetypeRemote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, archetypeId: unknown, ...)
		if select("#", ...) ~= 0 or typeof(archetypeId) ~= "string" then return end
		local starterOk = EconomyService._switchArchetypeForStudio(player, archetypeId)
		if starterOk then
			CombatCoordinator._setArchetypeForStudio(player, archetypeId)
		end
	end)
	levelConnection = (levelRemote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, level: unknown, ...)
		if select("#", ...) ~= 0 or typeof(level) ~= "number" then return end
		ProgressionService._setLevelForStudio(player, level)
	end)
	unlockRuinsConnection = (unlockRuinsRemote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then return end
		local definition = QuestDefinitions[DungeonUnlockRules.QuestId]
		assert(definition ~= nil, "Ruins unlock quest definition is missing")
		local mutated, reason = PlayerDataService.mutate(player, function(profile)
			DungeonUnlockRules.prepareStudioUnlock(profile.Quests, definition)
		end)
		if not mutated then
			warn(string.format("STUDIO: RUINS debug unlock rejected for userId=%d: %s", player.UserId, tostring(reason)))
		end
	end)
	speedConnection = (speedRemote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then return end
		local current = player:GetAttribute("StudioMovementMultiplier")
		CombatCoordinator._setMovementMultiplierForStudio(player, if current == 5 then 1 else 5)
	end)
end

function StudioDebugService.stop(): ()
	if not started then return end
	started = false
	if archetypeConnection ~= nil then archetypeConnection:Disconnect(); archetypeConnection = nil end
	if levelConnection ~= nil then levelConnection:Disconnect(); levelConnection = nil end
	if unlockRuinsConnection ~= nil then unlockRuinsConnection:Disconnect(); unlockRuinsConnection = nil end
	if speedConnection ~= nil then speedConnection:Disconnect(); speedConnection = nil end
	if archetypeRemote ~= nil then archetypeRemote:Destroy(); archetypeRemote = nil end
	if levelRemote ~= nil then levelRemote:Destroy(); levelRemote = nil end
	if unlockRuinsRemote ~= nil then unlockRuinsRemote:Destroy(); unlockRuinsRemote = nil end
	if speedRemote ~= nil then speedRemote:Destroy(); speedRemote = nil end
end

return StudioDebugService
