--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatCoordinator = require(script.Parent.Parent.features.combat.CombatCoordinator)
local EconomyService = require(script.Parent.EconomyService)
local ProgressionService = require(script.Parent.ProgressionService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local QuestDefinitions = require(ReplicatedStorage.Shared.definitions.QuestDefinitions)
local DungeonUnlockRules = require(ReplicatedStorage.Shared.dungeon.DungeonUnlockRules)
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)

local StudioDebugService = {}

local archetypeRemote: RemoteEvent? = nil
local levelRemote: RemoteEvent? = nil
local unlockRuinsRemote: RemoteEvent? = nil
local speedRemote: RemoteEvent? = nil
local unlockAllMissionsRemote: RemoteEvent? = nil
local topGearRemote: RemoteEvent? = nil
local teleportRemote: RemoteEvent? = nil
local archetypeConnection: RBXScriptConnection? = nil
local levelConnection: RBXScriptConnection? = nil
local unlockRuinsConnection: RBXScriptConnection? = nil
local speedConnection: RBXScriptConnection? = nil
local unlockAllMissionsConnection: RBXScriptConnection? = nil
local topGearConnection: RBXScriptConnection? = nil
local teleportConnection: RBXScriptConnection? = nil
local started = false

local STUDIO_TELEPORT_POIS: { [string]: string } = table.freeze({
	village = "poi_village_square",
	farm = "poi_moonfall_farm",
	moonfall = "poi_moonfall_crossroads",
	goblins = "poi_goblin_camp",
	spiders = "poi_spider_hollow",
	woodland = "entry_dark_woodland",
	cemetery = "poi_old_cemetery",
	shrine = "poi_fallen_shrine",
	ancient = "poi_ancient_approach",
})

local TOP_GEAR_BY_ARCHETYPE: { [string]: { [string]: string } } = table.freeze({
	knight = table.freeze({
		Weapon = "weapon_moonsteel_sword",
		Head = "armor_guard_head",
		Chest = "armor_guard_chest",
		Gloves = "armor_guard_gloves",
		Boots = "armor_guard_boots",
		Accessory = "accessory_lunar_sigil",
	}),
	ranger = table.freeze({
		Weapon = "weapon_moonstring_bow",
		Head = "armor_hunter_head",
		Chest = "armor_hunter_chest",
		Gloves = "armor_hunter_gloves",
		Boots = "armor_hunter_boots",
		Accessory = "accessory_lunar_sigil",
	}),
	mystic = table.freeze({
		Weapon = "weapon_moonveil_staff",
		Head = "armor_adept_head",
		Chest = "armor_adept_chest",
		Gloves = "armor_adept_gloves",
		Boots = "armor_adept_boots",
		Accessory = "accessory_lunar_sigil",
	}),
})

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

local function completeAllMissionsForStudio(player: Player): ()
	local mutated, reason = PlayerDataService.mutate(player, function(profile)
		for questId, definition in QuestDefinitions do
			local progress: { [string]: number } = {}
			for _, objective in definition.objectives do
				progress[objective.id] = objective.required
			end
			profile.Quests[questId] = {
				State = "Completed",
				Progress = progress,
			}
		end
	end)
	if not mutated then
		warn(string.format("STUDIO: all-missions unlock rejected for userId=%d: %s", player.UserId, tostring(reason)))
		return
	end
	player:SetAttribute("StudioAllMissionsOpen", true)
end

local function removeInventoryInstance(profile: any, instanceId: string): ()
	for index = #profile.Inventory, 1, -1 do
		if profile.Inventory[index] == instanceId then
			table.remove(profile.Inventory, index)
		end
	end
end

local function equipTopGearForStudio(player: Player): ()
	if not ProgressionService._setLevelForStudio(player, ProgressionConfig.LevelCap) then
		warn(string.format("STUDIO: top gear rejected for userId=%d because profile is not ready", player.UserId))
		return
	end

	local mutated, reason = PlayerDataService.mutate(player, function(profile)
		local gear = TOP_GEAR_BY_ARCHETYPE[profile.ArchetypeId]
		if gear == nil then
			error("Unknown archetype for Studio top gear: " .. tostring(profile.ArchetypeId))
		end
		local equipment: any = profile.Equipment
		for slot, itemId in gear do
			local instanceId = "__studio_top_" .. string.lower(slot)
			local previous = equipment[slot]
			if previous ~= nil and previous ~= instanceId then
				profile.Items[previous] = nil
			end
			removeInventoryInstance(profile, instanceId)
			profile.Items[instanceId] = {
				ItemId = itemId,
				Quantity = 1,
			}
			equipment[slot] = instanceId
		end
	end)
	if not mutated then
		warn(string.format("STUDIO: top gear mutation rejected for userId=%d: %s", player.UserId, tostring(reason)))
		return
	end
	player:SetAttribute("StudioTopGearReady", true)
end

local function findPoiPosition(poiId: string): Vector3?
	for _, poi in WorldLayout.PointsOfInterest do
		if poi.id == poiId then
			return poi.position
		end
	end
	return nil
end

local function resolveTeleportTarget(destinationId: string): Vector3?
	if destinationId == "ruins" then
		return WorldLayout.RuinsOfSeleneEntranceQuery
	end
	local poiId = STUDIO_TELEPORT_POIS[destinationId]
	return if poiId ~= nil then findPoiPosition(poiId) else nil
end

local function groundTeleportTarget(target: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local include: { Instance } = { workspace.Terrain }
	local world = workspace:FindFirstChild("LunaWorldPlayableBlockout")
	if world ~= nil then
		table.insert(include, world)
	end
	params.FilterDescendantsInstances = include
	params.IgnoreWater = false

	local originY = math.max(target.Y + 600, 900)
	local result = workspace:Raycast(
		Vector3.new(target.X, originY, target.Z),
		Vector3.new(0, -1800, 0),
		params
	)
	return if result ~= nil then result.Position + Vector3.new(0, 5, 0) else target + Vector3.new(0, 10, 0)
end

local function teleportForStudio(player: Player, destinationId: string): ()
	local target = resolveTeleportTarget(destinationId)
	if target == nil then return end
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return
	end

	local destination = groundTeleportTarget(target)
	local moved, moveReason = pcall(function()
		character:PivotTo(CFrame.new(destination))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
	if not moved then
		warn(string.format("STUDIO: teleport %s failed for userId=%d: %s", destinationId, player.UserId, tostring(moveReason)))
	end
end

function StudioDebugService.start(): ()
	if started or not RunService:IsStudio() then return end
	started = true
	archetypeRemote = createRemote("StudioSetArchetype")
	levelRemote = createRemote("StudioSetLevel")
	unlockRuinsRemote = createRemote("StudioUnlockRuins")
	speedRemote = createRemote("StudioToggleSpeed")
	unlockAllMissionsRemote = createRemote("StudioUnlockAllMissions")
	topGearRemote = createRemote("StudioGrantTopGear")
	teleportRemote = createRemote("StudioTeleport")
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
	unlockAllMissionsConnection = (unlockAllMissionsRemote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then return end
		completeAllMissionsForStudio(player)
	end)
	topGearConnection = (topGearRemote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, ...)
		if select("#", ...) ~= 0 then return end
		equipTopGearForStudio(player)
	end)
	teleportConnection = (teleportRemote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, destinationId: unknown, ...)
		if select("#", ...) ~= 0 or typeof(destinationId) ~= "string" then return end
		if destinationId ~= "ruins" and STUDIO_TELEPORT_POIS[destinationId] == nil then return end
		teleportForStudio(player, destinationId)
	end)
end

function StudioDebugService.stop(): ()
	if not started then return end
	started = false
	if archetypeConnection ~= nil then archetypeConnection:Disconnect(); archetypeConnection = nil end
	if levelConnection ~= nil then levelConnection:Disconnect(); levelConnection = nil end
	if unlockRuinsConnection ~= nil then unlockRuinsConnection:Disconnect(); unlockRuinsConnection = nil end
	if speedConnection ~= nil then speedConnection:Disconnect(); speedConnection = nil end
	if unlockAllMissionsConnection ~= nil then unlockAllMissionsConnection:Disconnect(); unlockAllMissionsConnection = nil end
	if topGearConnection ~= nil then topGearConnection:Disconnect(); topGearConnection = nil end
	if teleportConnection ~= nil then teleportConnection:Disconnect(); teleportConnection = nil end
	if archetypeRemote ~= nil then archetypeRemote:Destroy(); archetypeRemote = nil end
	if levelRemote ~= nil then levelRemote:Destroy(); levelRemote = nil end
	if unlockRuinsRemote ~= nil then unlockRuinsRemote:Destroy(); unlockRuinsRemote = nil end
	if speedRemote ~= nil then speedRemote:Destroy(); speedRemote = nil end
	if unlockAllMissionsRemote ~= nil then unlockAllMissionsRemote:Destroy(); unlockAllMissionsRemote = nil end
	if topGearRemote ~= nil then topGearRemote:Destroy(); topGearRemote = nil end
	if teleportRemote ~= nil then teleportRemote:Destroy(); teleportRemote = nil end
end

return StudioDebugService
