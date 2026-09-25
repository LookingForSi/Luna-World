--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local Layout = require(ReplicatedStorage.Shared.dungeon.DungeonLayout)
local RespawnConfig = require(ReplicatedStorage.Shared.config.RespawnConfig)

local Service = {}
local root: Folder? = nil
local origin = CFrame.identity

local STONE = Color3.fromRGB(62, 65, 78)
local ROOM_COLORS = {
	Color3.fromRGB(57, 64, 78),
	Color3.fromRGB(66, 62, 80),
	Color3.fromRGB(73, 65, 82),
	Color3.fromRGB(61, 70, 84),
	Color3.fromRGB(76, 63, 83),
	Color3.fromRGB(58, 72, 82),
}

local function part(parent: Instance, name: string, size: Vector3, localPosition: Vector3, color: Color3): Part
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.CFrame = origin * CFrame.new(localPosition)
	value.Anchored = true
	value.Color = color
	value.Parent = parent
	return value
end

local function room(parent: Instance, definition: any, index: number): ()
	local length = definition.endZ - definition.startZ
	local centerZ = (definition.startZ + definition.endZ) * 0.5
	part(parent, definition.id .. "Floor", Vector3.new(definition.width, 4, length), Vector3.new(0, -2, centerZ), ROOM_COLORS[index])
	part(parent, definition.id .. "WallL", Vector3.new(4, 30, length), Vector3.new(-definition.width * 0.5 - 2, 13, centerZ), STONE)
	part(parent, definition.id .. "WallR", Vector3.new(4, 30, length), Vector3.new(definition.width * 0.5 + 2, 13, centerZ), STONE)

	local marker = part(parent, definition.id .. "RoomMarker", Vector3.new(18, 1, 4), Vector3.new(0, 0.5, definition.startZ + 8), ROOM_COLORS[index])
	marker.CanCollide = false
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.35
	marker:SetAttribute("RoomId", definition.id)
	marker:SetAttribute("DisplayName", definition.displayName)
end

function Service.toWorld(localPosition: Vector3): Vector3
	return origin:PointToWorldSpace(localPosition)
end

function Service.toLocal(worldPosition: Vector3): Vector3
	return origin:PointToObjectSpace(worldPosition)
end

function Service.inspectBounds(worldPosition: Vector3): (boolean, string?, Vector3)
	local position = Service.toLocal(worldPosition)
	if position.Y < Layout.OutOfBoundsY then return false, "Y", position end
	if math.abs(position.X) > Layout.RouteHalfWidth then return false, "X", position end
	if position.Z < Layout.RouteMinZ then return false, "minZ", position end
	if position.Z > Layout.RouteMaxZ then return false, "maxZ", position end
	return true, nil, position
end

function Service.isWithinBounds(worldPosition: Vector3): boolean
	local within = Service.inspectBounds(worldPosition)
	return within
end

function Service.getOrigin(): Vector3 return origin.Position end

function Service.getRoot(): Folder?
	return root
end

function Service.getRetreatPrompt(): ProximityPrompt?
	if root == nil then return nil end
	local spawn = root:FindFirstChild("DungeonEntranceSpawn")
	if spawn == nil then return nil end
	return spawn:FindFirstChild(Config.RetreatPromptName) :: ProximityPrompt?
end

function Service.getCheckpoint(index: number): BasePart?
	return if root ~= nil then root:FindFirstChild("Checkpoint" .. tostring(math.clamp(index, 0, 3))) :: BasePart? else nil
end

function Service.setGateClosed(index: number, closed: boolean): ()
	if root == nil then return end
	local name = "AuthoritativeGate" .. tostring(index)
	local gate = root:FindFirstChild(name)
	if not closed then
		if gate ~= nil then gate:Destroy() end
		return
	end
	if gate ~= nil then return end
	local created = part(root, name, Vector3.new(Layout.CorridorWidth, 26, 4), Vector3.new(0, 11, Layout.GateZ[index]), Color3.fromRGB(80, 55, 95))
	created:SetAttribute("EncounterGate", index)
end

function Service.start(devCombined: boolean?): ()
	if root ~= nil then return end
	origin = if devCombined == true then CFrame.new(Layout.DevCombinedOffset) else CFrame.identity
	root = Instance.new("Folder")
	root.Name = "RuinsOfSelene"
	root:SetAttribute("DevCombinedIsolated", devCombined == true)
	root:SetAttribute("Origin", origin.Position)
	root.Parent = workspace

	for index, definition in Layout.Rooms do room(root, definition, index) end
	part(root, "RouteStartWall", Vector3.new(Layout.CorridorWidth + 8, 30, 4), Vector3.new(0, 13, Layout.Rooms[1].startZ), STONE)
	part(root, "RouteEndWall", Vector3.new(Layout.CorridorWidth + 8, 30, 4), Vector3.new(0, 13, Layout.Rooms[#Layout.Rooms].endZ), STONE)
	for index = 1, 3 do Service.setGateClosed(index, true) end

	for index, position in Layout.CheckpointPositions do
		local checkpoint = part(root, "Checkpoint" .. tostring(index - 1), Vector3.new(10, 1, 10), position, Color3.fromRGB(70, 105, 125))
		checkpoint.Transparency = 0.5
		checkpoint.CanCollide = false
		checkpoint:SetAttribute(RespawnConfig.SettlementIdAttribute, "dungeon_selene")
		checkpoint:SetAttribute(RespawnConfig.AnchorIdAttribute, "selene_checkpoint_" .. tostring(index - 1))
		CollectionService:AddTag(checkpoint, RespawnConfig.AnchorTag)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "DungeonEntranceSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = origin * CFrame.new(Layout.EntrancePosition)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = root

	local retreatPrompt = Instance.new("ProximityPrompt")
	retreatPrompt.Name = Config.RetreatPromptName
	retreatPrompt.ActionText = "Покинуть руины"
	retreatPrompt.ObjectText = "Пьедестал возвращения"
	retreatPrompt.Enabled = true
	retreatPrompt.RequiresLineOfSight = false
	retreatPrompt.MaxActivationDistance = 12
	retreatPrompt.Parent = spawn

	local exit = part(root, Config.ExitPromptName, Vector3.new(12, 1, 12), Layout.ExitPosition, Color3.fromRGB(90, 120, 150))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Вернуться в Moonfall"
	prompt.ObjectText = "Выход"
	prompt.Enabled = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = exit
end

function Service.stop(): ()
	if root ~= nil then root:Destroy(); root = nil end
	origin = CFrame.identity
end

return Service
