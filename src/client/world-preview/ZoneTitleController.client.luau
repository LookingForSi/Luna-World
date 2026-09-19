--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CHECK_INTERVAL_SECONDS = 0.2
local FADE_IN_SECONDS = 0.2
local HOLD_SECONDS = 2.0
local FADE_OUT_SECONDS = 0.45

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WorldZoneTitleGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local title = Instance.new("TextLabel")
title.Name = "ZoneTitle"
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.fromScale(0.5, 0.12)
title.Size = UDim2.fromOffset(520, 48)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamMedium
title.TextColor3 = Color3.fromRGB(239, 236, 225)
title.TextSize = 28
title.TextStrokeColor3 = Color3.fromRGB(18, 20, 22)
title.TextStrokeTransparency = 0.35
title.TextTransparency = 1
title.Visible = true
title.Parent = screenGui

local currentZoneId: string? = nil
local presentationGeneration = 0

local function getCharacterPosition(): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	return root.Position
end

local function pointInsidePart(part: BasePart, worldPosition: Vector3): boolean
	local localPosition = part.CFrame:PointToObjectSpace(worldPosition)
	local halfSize = part.Size / 2

	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function findZoneTrigger(worldPosition: Vector3): BasePart?
	local worldRoot = workspace:FindFirstChild("LunaWorldGreybox")
	if worldRoot == nil then
		return nil
	end

	local presentation = worldRoot:FindFirstChild("Presentation")
	if presentation == nil then
		return nil
	end

	local triggers = presentation:FindFirstChild("ZoneTriggers")
	if triggers == nil then
		return nil
	end

	local bestTrigger: BasePart? = nil
	local bestPriority = -math.huge

	for _, child in ipairs(triggers:GetChildren()) do
		if child:IsA("BasePart") and pointInsidePart(child, worldPosition) then
			local priority = child:GetAttribute("Priority")
			local numericPriority = if type(priority) == "number" then priority else 0
			if numericPriority > bestPriority then
				bestPriority = numericPriority
				bestTrigger = child
			end
		end
	end

	return bestTrigger
end

local function showZoneTitle(displayName: string)
	presentationGeneration += 1
	local generation = presentationGeneration

	title.Text = displayName
	title.TextTransparency = 1

	TweenService:Create(
		title,
		TweenInfo.new(FADE_IN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	):Play()

	task.delay(FADE_IN_SECONDS + HOLD_SECONDS, function()
		if generation ~= presentationGeneration then
			return
		end

		TweenService:Create(
			title,
			TweenInfo.new(FADE_OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		):Play()
	end)
end

local elapsed = 0
RunService.Heartbeat:Connect(function(deltaTime)
	elapsed += deltaTime
	if elapsed < CHECK_INTERVAL_SECONDS then
		return
	end
	elapsed = 0

	local position = getCharacterPosition()
	if position == nil then
		return
	end

	local trigger = findZoneTrigger(position)
	local nextZoneId: string? = nil
	local displayName: string? = nil

	if trigger ~= nil then
		local zoneIdAttribute = trigger:GetAttribute("ZoneId")
		local displayNameAttribute = trigger:GetAttribute("DisplayName")
		if type(zoneIdAttribute) == "string" then
			nextZoneId = zoneIdAttribute
		end
		if type(displayNameAttribute) == "string" then
			displayName = displayNameAttribute
		end
	end

	if nextZoneId ~= currentZoneId then
		currentZoneId = nextZoneId
		if nextZoneId ~= nil and displayName ~= nil then
			showZoneTitle(displayName)
		end
	end
end)
