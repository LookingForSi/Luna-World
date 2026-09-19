--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)

local TraversalRecovery = {}

local CHECK_INTERVAL = 0.2
local FALL_RECOVERY_Y = -24
local RECOVERY_OFFSET = Vector3.new(0, 5, 0)
local SAFE_SAMPLE_MAX_ABOVE_TERRAIN = 28
local BOUNDS_MARGIN = 10

local function collectWaterHazards(worldRoot: Instance): { BasePart }
	local hazards: { BasePart } = {}
	for _, descendant in ipairs(worldRoot:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("WaterRecovery") == true then
			table.insert(hazards, descendant)
		end
	end
	return hazards
end

local function containsPoint(part: BasePart, position: Vector3): boolean
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y
		and math.abs(localPosition.Z) <= half.Z
end

local function isInsideWaterHazard(hazards: { BasePart }, position: Vector3): boolean
	for _, hazard in ipairs(hazards) do
		if hazard.Parent ~= nil and containsPoint(hazard, position) then
			return true
		end
	end
	return false
end

local function insidePlayableBounds(position: Vector3): boolean
	local bounds = WorldLayout.WorldBounds
	return position.X >= bounds.minX + BOUNDS_MARGIN
		and position.X <= bounds.maxX - BOUNDS_MARGIN
		and position.Z >= bounds.minZ + BOUNDS_MARGIN
		and position.Z <= bounds.maxZ - BOUNDS_MARGIN
end

local function terrainSurfaceY(position: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true

	local result = workspace:Raycast(
		Vector3.new(position.X, position.Y + 40, position.Z),
		Vector3.new(0, -120, 0),
		params
	)
	if result == nil then
		return nil
	end
	return result.Position.Y
end

local function isSafeGroundedPosition(
	humanoid: Humanoid,
	rootPart: BasePart,
	hazards: { BasePart }
): boolean
	if humanoid.Health <= 0 or humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end
	if not insidePlayableBounds(rootPart.Position) or isInsideWaterHazard(hazards, rootPart.Position) then
		return false
	end

	local surfaceY = terrainSurfaceY(rootPart.Position)
	if surfaceY == nil then
		return false
	end

	local aboveTerrain = rootPart.Position.Y - surfaceY
	return aboveTerrain >= 0 and aboveTerrain <= SAFE_SAMPLE_MAX_ABOVE_TERRAIN
end

local function clearVelocity(rootPart: BasePart)
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

function TraversalRecovery.start(worldRoot: Instance, spawn: SpawnLocation)
	local hazards = collectWaterHazards(worldRoot)
	local lastSafe: { [Player]: CFrame } = {}

	local function spawnCFrame(): CFrame
		return spawn.CFrame + RECOVERY_OFFSET
	end

	local function registerPlayer(player: Player)
		player.RespawnLocation = spawn
		lastSafe[player] = spawnCFrame()
	end

	for _, player in ipairs(Players:GetPlayers()) do
		registerPlayer(player)
	end

	Players.PlayerAdded:Connect(registerPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lastSafe[player] = nil
	end)

	task.spawn(function()
		while worldRoot.Parent ~= nil do
			task.wait(CHECK_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				if character == nil then
					continue
				end

				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if humanoid == nil or rootPart == nil or not rootPart:IsA("BasePart") then
					continue
				end

				local fellOut = rootPart.Position.Y < FALL_RECOVERY_Y
				local fellIntoRiver = isInsideWaterHazard(hazards, rootPart.Position)
				if fellOut or fellIntoRiver then
					character:PivotTo(lastSafe[player] or spawnCFrame())
					clearVelocity(rootPart)
				elseif isSafeGroundedPosition(humanoid, rootPart, hazards) then
					lastSafe[player] = character:GetPivot()
				end
			end
		end
	end)
end

return table.freeze(TraversalRecovery)
