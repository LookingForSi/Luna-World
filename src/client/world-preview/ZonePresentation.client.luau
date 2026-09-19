--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "WorldPreviewGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local banner = Instance.new("Frame")
banner.Name = "ZoneToast"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.fromScale(0.5, 0.075)
banner.Size = UDim2.fromOffset(360, 58)
banner.BackgroundColor3 = Color3.fromRGB(19, 21, 25)
banner.BackgroundTransparency = 1
banner.BorderSizePixel = 0
banner.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = banner

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 5)
title.Size = UDim2.new(1, -28, 0, 28)
title.Font = Enum.Font.GothamMedium
title.TextColor3 = Color3.fromRGB(238, 238, 232)
title.TextSize = 22
title.TextTransparency = 1
title.Text = ""
title.Parent = banner

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(14, 32)
subtitle.Size = UDim2.new(1, -28, 0, 18)
subtitle.Font = Enum.Font.Gotham
subtitle.TextColor3 = Color3.fromRGB(178, 181, 184)
subtitle.TextSize = 13
subtitle.TextTransparency = 1
subtitle.Text = ""
subtitle.Parent = banner

type ZoneDefinition = typeof(WorldLayout.Zones[1])

local zoneById: { [string]: ZoneDefinition } = {}
for _, zone in ipairs(WorldLayout.Zones) do
	zoneById[zone.id] = zone
end

local currentZoneId: string? = nil
local toastGeneration = 0

local function findZone(position: Vector3): string?
	local bestZoneId: string? = nil
	local bestPriority = -math.huge

	for _, volume in ipairs(WorldLayout.ZoneVolumes) do
		local half = volume.size / 2
		local insideX = math.abs(position.X - volume.center.X) <= half.X
		local insideZ = math.abs(position.Z - volume.center.Z) <= half.Z
		if insideX and insideZ and volume.priority > bestPriority then
			bestZoneId = volume.zoneId
			bestPriority = volume.priority
		end
	end

	return bestZoneId
end

local function showZone(zoneId: string)
	local zone = zoneById[zoneId]
	if zone == nil then
		return
	end

	toastGeneration += 1
	local generation = toastGeneration

	title.Text = zone.displayName
	subtitle.Text = string.format("Уровни %d–%d", zone.levelMin, zone.levelMax)

	TweenService:Create(banner, TweenInfo.new(0.18), { BackgroundTransparency = 0.2 }):Play()
	TweenService:Create(title, TweenInfo.new(0.18), { TextTransparency = 0 }):Play()
	TweenService:Create(subtitle, TweenInfo.new(0.18), { TextTransparency = 0.12 }):Play()

	task.delay(2.5, function()
		if generation ~= toastGeneration then
			return
		end
		TweenService:Create(banner, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(title, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(subtitle, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
	end)
end

local function hideTouchJumpButton()
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if touchGui == nil then
		return
	end
	local jumpButton = touchGui:FindFirstChild("JumpButton", true)
	if jumpButton ~= nil and jumpButton:IsA("GuiObject") then
		jumpButton.Visible = false
	end
end

local function disableJump(character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	if humanoid:IsA("Humanoid") then
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
	task.defer(hideTouchJumpButton)
end

ContextActionService:BindActionAtPriority(
	"LunaWorldPreviewDisableJump",
	function()
		return Enum.ContextActionResult.Sink
	end,
	false,
	3000,
	Enum.KeyCode.Space,
	Enum.KeyCode.ButtonA
)

player.CharacterAdded:Connect(disableJump)
if player.Character ~= nil then
	task.spawn(disableJump, player.Character)
end

task.spawn(function()
	while true do
		task.wait(0.18)
		local character = player.Character
		local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if rootPart ~= nil and rootPart:IsA("BasePart") then
			local zoneId = findZone(rootPart.Position)
			if zoneId ~= nil and zoneId ~= currentZoneId then
				currentZoneId = zoneId
				showZone(zoneId)
			elseif zoneId == nil then
				currentZoneId = nil
			end
		end
	end
end)
