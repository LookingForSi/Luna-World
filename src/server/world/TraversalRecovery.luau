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

local started = false
local serviceGeneration = 0
local connections: { RBXScriptConnection } = {}
local lastSafe: { [Player]: CFrame } = {}
local excluded: { [Player]: boolean } = {}

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

local function isSafeGroundedPosition(humanoid: Humanoid, rootPart: BasePart): boolean
	if humanoid.Health <= 0
		or humanoid:GetState() == Enum.HumanoidStateType.Swimming
		or humanoid.FloorMaterial == Enum.Material.Air
	then
		return false
	end
	if not insidePlayableBounds(rootPart.Position) then
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
	if started then
		return
	end
	started = true
	serviceGeneration += 1
	local expectedGeneration = serviceGeneration

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

	table.insert(connections, Players.PlayerAdded:Connect(registerPlayer))
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		lastSafe[player] = nil
		excluded[player] = nil
	end))

	task.spawn(function()
		while started and serviceGeneration == expectedGeneration and worldRoot.Parent ~= nil do
			task.wait(CHECK_INTERVAL)
			if not started or serviceGeneration ~= expectedGeneration then
				break
			end

			for _, player in ipairs(Players:GetPlayers()) do
				if excluded[player] then
					continue
				end
				local character = player.Character
				if character == nil then
					continue
				end

				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if humanoid == nil or rootPart == nil or not rootPart:IsA("BasePart") then
					continue
				end

				-- Terrain water is valid traversal. Recovery only handles genuine
				-- out-of-world failures; swimming never teleports the player.
				local fellOut = rootPart.Position.Y < FALL_RECOVERY_Y
				local leftBounds = not insidePlayableBounds(rootPart.Position)
				if fellOut or leftBounds then
					character:PivotTo(lastSafe[player] or spawnCFrame())
					clearVelocity(rootPart)
				elseif isSafeGroundedPosition(humanoid, rootPart) then
					lastSafe[player] = character:GetPivot()
				end
			end
		end
	end)
end

-- DevCombined temporarily puts admitted players outside Moonfall's authored bounds.
-- Its transport adapter owns this exception; production dungeon servers never call it.
function TraversalRecovery.setPlayerExcluded(player: Player, value: boolean): ()
	excluded[player] = if value then true else nil
end

function TraversalRecovery.stop(): ()
	if not started then
		return
	end
	started = false
	serviceGeneration += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(lastSafe)
	table.clear(excluded)
end

return table.freeze(TraversalRecovery)
