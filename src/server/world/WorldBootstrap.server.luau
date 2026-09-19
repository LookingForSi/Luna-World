--!strict

local Players = game:GetService("Players")

local PlayableWorldBlockout = require(script.Parent.PlayableWorldBlockout)

local root, spawn = PlayableWorldBlockout.rebuild()

local RECOVERY_Y = -24
local RECOVERY_OFFSET = Vector3.new(0, 6, 0)

local function placeAtSpawn(player: Player)
	player.RespawnLocation = spawn
	local character = player.Character
	if character ~= nil then
		task.defer(function()
			character:PivotTo(spawn.CFrame + RECOVERY_OFFSET)
		end)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	placeAtSpawn(player)
end

Players.PlayerAdded:Connect(function(player)
	player.RespawnLocation = spawn
end)

task.spawn(function()
	while root.Parent ~= nil do
		task.wait(0.4)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character ~= nil then
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart ~= nil and rootPart:IsA("BasePart") and rootPart.Position.Y < RECOVERY_Y then
					character:PivotTo(spawn.CFrame + RECOVERY_OFFSET)
					rootPart.AssemblyLinearVelocity = Vector3.zero
					rootPart.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end
	end
end)
