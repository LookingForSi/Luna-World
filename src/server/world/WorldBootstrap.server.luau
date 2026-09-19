--!strict

local Players = game:GetService("Players")

local WorldGreyboxBuilder = require(script.Parent.WorldGreyboxBuilder)

local world = WorldGreyboxBuilder.rebuild(workspace)
local presentation = world:WaitForChild("Presentation")
local spawnInstance = presentation:WaitForChild("WorldSpawn")

assert(spawnInstance:IsA("SpawnLocation"), "World preview requires Presentation/WorldSpawn")
local worldSpawn = spawnInstance :: SpawnLocation

local function placeCharacterAtWorldSpawn(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or not root:IsA("BasePart") then
		return
	end

	character:PivotTo(worldSpawn.CFrame + Vector3.new(0, 4, 0))
end

local function configurePlayer(player: Player)
	player.RespawnLocation = worldSpawn

	player.CharacterAdded:Connect(function(character)
		task.defer(placeCharacterAtWorldSpawn, character)
	end)

	if player.Character ~= nil then
		task.defer(placeCharacterAtWorldSpawn, player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	configurePlayer(player)
end

Players.PlayerAdded:Connect(configurePlayer)
