--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WorldGreyboxBuilder = require(script.Parent.WorldGreyboxBuilder)

local SAFETY_CHECK_INTERVAL = 0.15
local UNSAFE_GRACE_SECONDS = 0.45
local SAFE_INSET = 12

type SafetyState = {
	lastSafeCFrame: CFrame,
	unsafeSince: number?,
}

local world = WorldGreyboxBuilder.rebuild(workspace)
local presentation = world:WaitForChild("Presentation")
local spawnInstance = presentation:WaitForChild("WorldSpawn")
local zoneTriggersInstance = presentation:WaitForChild("ZoneTriggers")

assert(spawnInstance:IsA("SpawnLocation"), "World preview requires Presentation/WorldSpawn")
assert(zoneTriggersInstance:IsA("Folder"), "World preview requires Presentation/ZoneTriggers")

local worldSpawn = spawnInstance :: SpawnLocation
local zoneTriggers = zoneTriggersInstance :: Folder
local safetyStateByPlayer: { [Player]: SafetyState } = {}

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	return root
end

local function pointInsideTriggerXZ(trigger: BasePart, worldPosition: Vector3, inset: number): boolean
	local localPosition = trigger.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = trigger.Size / 2
	local halfX = math.max(0, halfSize.X - inset)
	local halfZ = math.max(0, halfSize.Z - inset)

	return math.abs(localPosition.X) <= halfX and math.abs(localPosition.Z) <= halfZ
end

local function isSafeWorldPosition(worldPosition: Vector3, inset: number): boolean
	for _, child in ipairs(zoneTriggers:GetChildren()) do
		if child:IsA("BasePart") and pointInsideTriggerXZ(child, worldPosition, inset) then
			local minSafeY = child:GetAttribute("MinSafeY")
			if type(minSafeY) == "number" and worldPosition.Y >= minSafeY then
				return true
			end
		end
	end

	return false
end

local function placeCharacterAtWorldSpawn(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or not root:IsA("BasePart") then
		return
	end

	character:PivotTo(worldSpawn.CFrame + Vector3.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function recoverPlayer(player: Player, state: SafetyState)
	local character = player.Character
	local root = getCharacterRoot(player)
	if character == nil or root == nil then
		return
	end

	character:PivotTo(state.lastSafeCFrame)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	state.unsafeSince = nil
end

local function configurePlayer(player: Player)
	player.RespawnLocation = worldSpawn

	local state: SafetyState = {
		lastSafeCFrame = worldSpawn.CFrame + Vector3.new(0, 4, 0),
		unsafeSince = nil,
	}
	safetyStateByPlayer[player] = state

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			placeCharacterAtWorldSpawn(character)
			state.lastSafeCFrame = worldSpawn.CFrame + Vector3.new(0, 4, 0)
			state.unsafeSince = nil
		end)
	end)

	if player.Character ~= nil then
		task.defer(function()
			placeCharacterAtWorldSpawn(player.Character :: Model)
		end)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	configurePlayer(player)
end

Players.PlayerAdded:Connect(configurePlayer)
Players.PlayerRemoving:Connect(function(player)
	safetyStateByPlayer[player] = nil
end)

local safetyElapsed = 0
RunService.Heartbeat:Connect(function(deltaTime)
	safetyElapsed += deltaTime
	if safetyElapsed < SAFETY_CHECK_INTERVAL then
		return
	end
	safetyElapsed = 0

	local now = os.clock()
	for player, state in pairs(safetyStateByPlayer) do
		local root = getCharacterRoot(player)
		if root == nil then
			continue
		end

		local position = root.Position
		if isSafeWorldPosition(position, 0) then
			state.unsafeSince = nil
			if isSafeWorldPosition(position, SAFE_INSET) then
				state.lastSafeCFrame = root.CFrame
			end
		elseif state.unsafeSince == nil then
			state.unsafeSince = now
		elseif now - state.unsafeSince >= UNSAFE_GRACE_SECONDS then
			recoverPlayer(player, state)
		end
	end
end)
