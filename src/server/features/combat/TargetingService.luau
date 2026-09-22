--!strict

local Players = game:GetService("Players")

local TargetingService = {}

function TargetingService.getPlayerByCanonicalTargetId(targetId: string): Player?
	for _, candidate in Players:GetPlayers() do
		if targetId == "player:" .. tostring(candidate.UserId) then
			return candidate
		end
	end
	return nil
end

function TargetingService.facePlayerTowardModel(player: Player, target: Model): ()
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") or targetRoot == nil or not targetRoot:IsA("BasePart") then
		return
	end

	local origin = root.Position
	local horizontalTarget = Vector3.new(targetRoot.Position.X, origin.Y, targetRoot.Position.Z)
	if (horizontalTarget - origin).Magnitude <= 0.001 then
		return
	end
	root.CFrame = CFrame.lookAt(origin, horizontalTarget)
end

return table.freeze(TargetingService)
