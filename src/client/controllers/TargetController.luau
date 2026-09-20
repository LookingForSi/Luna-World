--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local TargetController = {}

local localPlayer = Players.LocalPlayer
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ClientCombatUiRules = require(ReplicatedStorage.Shared.combat.ClientCombatUiRules)
local targetRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TargetRequest") :: RemoteEvent
local TARGET_ATTRIBUTE = CombatConfig.SelectedTargetAttribute

local inputBeganConnection: RBXScriptConnection? = nil
local touchTapConnection: RBXScriptConnection? = nil
local targetAttributeConnection: RBXScriptConnection? = nil
local descendantAddedConnection: RBXScriptConnection? = nil
local selectedHighlight: Highlight? = nil
local onTargetChanged: ((Model?) -> ())? = nil
local selectedModel: Model? = nil
local TARGET_ACTION = "LunaCycleTarget"
local CLEAR_TARGET_ACTION = "LunaClearTarget"
local DESKTOP_PICK_PADDING = 52

local function findEntityModel(instance: Instance?): Model?
	local current = instance
	while current ~= nil and current ~= workspace do
		if current:IsA("Model") and typeof(current:GetAttribute("EntityId")) == "string" then
			return current
		end
		if current:IsA("Model") then
			local targetPlayer = Players:GetPlayerFromCharacter(current)
			if targetPlayer ~= nil and targetPlayer ~= localPlayer then return current end
		end
		current = current.Parent
	end
	return nil
end

local function findEntityModelById(entityId: string): Model?
	local userIdText = string.match(entityId, "^player:(%-?%d+)$")
	if userIdText ~= nil then
		local targetPlayer = Players:GetPlayerByUserId(tonumber(userIdText) :: number)
		return if targetPlayer ~= nil and targetPlayer ~= localPlayer then targetPlayer.Character else nil
	end
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("EntityId") == entityId then
			return descendant
		end
	end
	return nil
end

local function showConfirmedTarget(model: Model?): ()
	if selectedModel == model then
		return
	end

	selectedModel = model
	if selectedHighlight ~= nil then
		selectedHighlight:Destroy()
		selectedHighlight = nil
	end

	if model ~= nil then
		local highlight = Instance.new("Highlight")
		highlight.Name = "LocalTargetHighlight"
		highlight.Adornee = model
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = model
		selectedHighlight = highlight
	end

	if onTargetChanged ~= nil then
		onTargetChanged(model)
	end
end

local function syncConfirmedTarget(): ()
	local entityId = localPlayer:GetAttribute(TARGET_ATTRIBUTE)
	if typeof(entityId) ~= "string" then
		showConfirmedTarget(nil)
		return
	end

	showConfirmedTarget(findEntityModelById(entityId))
end

local function raycastEntity(screenPosition: Vector2): Model?
	local camera = workspace.CurrentCamera
	if camera == nil then return nil end

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local character = localPlayer.Character
	if character ~= nil then
		raycastParams.FilterDescendantsInstances = { character }
	end

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
	return if result ~= nil then findEntityModel(result.Instance) else nil
end

local function requestModel(model: Model?): ()
	if model == nil then return end

	local targetPlayer = Players:GetPlayerFromCharacter(model)
	if targetPlayer == localPlayer then return end
	local entityId = if targetPlayer ~= nil
		then ClientCombatUiRules.canonicalPlayerTargetId(targetPlayer.UserId)
		else model:GetAttribute("EntityId")
	if typeof(entityId) ~= "string" then return end

	-- Rendering waits for the server to validate and replicate the confirmed target.
	targetRequest:FireServer(entityId)
end

function TargetController.clearTarget(): ()
	targetRequest:FireServer("")
end

local function getScreenBounds(model: Model): (Vector2?, Vector2?, number?)
	local camera = workspace.CurrentCamera
	if camera == nil then return nil, nil, nil end

	local visibleRoot = model:FindFirstChild("HumanoidRootPart")
	local boxCFrame: CFrame
	local boxSize: Vector3
	if typeof(model:GetAttribute("MobId")) == "string"
		and visibleRoot ~= nil
		and visibleRoot:IsA("BasePart")
	then
		-- For placeholder mobs the HumanoidRootPart is the visible silhouette.
		-- Ignore the larger invisible TargetHitbox so forgiveness stays centered.
		boxCFrame = visibleRoot.CFrame
		boxSize = visibleRoot.Size
	else
		-- Player characters and future multipart entities keep their full visual bounds.
		boxCFrame, boxSize = model:GetBoundingBox()
	end
	local half = boxSize * 0.5
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local nearestDepth = math.huge
	local projected = false

	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local worldPoint = boxCFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
				local viewportPoint = camera:WorldToViewportPoint(worldPoint)
				if viewportPoint.Z > 0 then
					projected = true
					minX = math.min(minX, viewportPoint.X)
					minY = math.min(minY, viewportPoint.Y)
					maxX = math.max(maxX, viewportPoint.X)
					maxY = math.max(maxY, viewportPoint.Y)
					nearestDepth = math.min(nearestDepth, viewportPoint.Z)
				end
			end
		end
	end

	if not projected then return nil, nil, nil end
	return Vector2.new(minX, minY), Vector2.new(maxX, maxY), nearestDepth
end

local function findForgivingScreenCandidate(screenPosition: Vector2): Model?
	local localCharacter = localPlayer.Character
	local bestModel: Model? = nil
	local bestCenterDistance = math.huge
	local bestDepth = math.huge

	for _, child in workspace:GetChildren() do
		if not child:IsA("Model") or child == localCharacter then continue end
		local targetPlayer = Players:GetPlayerFromCharacter(child)
		local selectable = typeof(child:GetAttribute("EntityId")) == "string"
			or (targetPlayer ~= nil and targetPlayer ~= localPlayer)
		if not selectable then continue end

		local humanoid = child:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or humanoid.Health <= 0 then continue end

		local minimum, maximum, depth = getScreenBounds(child)
		if minimum == nil or maximum == nil or depth == nil then continue end
		if ClientCombatUiRules.screenRectDistance(screenPosition, minimum, maximum, DESKTOP_PICK_PADDING) > 0 then
			continue
		end

		local center = (minimum + maximum) * 0.5
		local centerDistance = (center - screenPosition).Magnitude
		if centerDistance < bestCenterDistance
			or (centerDistance == bestCenterDistance and depth < bestDepth)
		then
			bestModel = child
			bestCenterDistance = centerDistance
			bestDepth = depth
		end
	end

	return bestModel
end

local function selectAtScreenPosition(screenPosition: Vector2, touchInput: boolean): ()
	-- InputObject.Position / TouchTap already line up with Camera viewport
	-- coordinates in the supported runtime. Subtracting GuiInset shifted the
	-- entire pick ray above the rendered silhouette.
	local exact = raycastEntity(screenPosition)
	if exact ~= nil then
		requestModel(exact)
		return
	end

	if touchInput then
		for _, offset in ClientCombatUiRules.getTouchProbeOffsets(30) do
			local model = raycastEntity(screenPosition + offset)
			if model ~= nil then
				requestModel(model)
				return
			end
		end
	end

	local forgiving = findForgivingScreenCandidate(screenPosition)
	if forgiving ~= nil then requestModel(forgiving) end
end

local function requestNearestVisibleTarget(): ()
	local character = localPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then return end
	local candidates: { { model: Model, distance: number, id: string } } = {}
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and child ~= character then
			local targetPlayer = Players:GetPlayerFromCharacter(child)
			local selectable = typeof(child:GetAttribute("EntityId")) == "string"
				or (targetPlayer ~= nil and targetPlayer ~= localPlayer)
			if not selectable then continue end
			local candidateRoot = child:FindFirstChild("HumanoidRootPart")
			local humanoid = child:FindFirstChildOfClass("Humanoid")
			if candidateRoot ~= nil and candidateRoot:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0 then
				local distance = (candidateRoot.Position - root.Position).Magnitude
				local id = if targetPlayer ~= nil
					then ClientCombatUiRules.canonicalPlayerTargetId(targetPlayer.UserId)
					else child:GetAttribute("EntityId")
				if typeof(id) == "string" then table.insert(candidates, { model = child, distance = distance, id = id }) end
			end
		end
	end
	table.sort(candidates, function(left, right)
		if left.distance == right.distance then return left.id < right.id end
		return left.distance < right.distance
	end)
	if #candidates == 0 then return end
	local selectedId = localPlayer:GetAttribute(TARGET_ATTRIBUTE)
	local nextIndex = 1
	for index, candidate in candidates do
		if candidate.id == selectedId then nextIndex = (index % #candidates) + 1 break end
	end
	requestModel(candidates[nextIndex].model) -- The server still enforces eligibility and selection range.
end

function TargetController.start(targetChanged: (Model?) -> ()): ()
	TargetController.stop()
	onTargetChanged = targetChanged

	inputBeganConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- Desktop clear-target shortcut. Do not sink the input so Roblox camera
			-- rotation can still use the right mouse button naturally.
			TargetController.clearTarget()
			return
		end
		-- Touch is handled only by TouchTap so one tap cannot issue two requests.
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		selectAtScreenPosition(Vector2.new(input.Position.X, input.Position.Y), false)
	end)

	touchTapConnection = UserInputService.TouchTap:Connect(function(touchPositions: { Vector2 }, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		local position = touchPositions[1]
		if position ~= nil then
			selectAtScreenPosition(position, true)
		end
	end)
	ContextActionService:BindAction(TARGET_ACTION, function(_, state, inputObject)
		if ClientCombatUiRules.shouldIgnoreForGuiNavigation(inputObject.UserInputType.Name, GuiService.SelectedObject ~= nil) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then requestNearestVisibleTarget() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Tab, Enum.KeyCode.ButtonR3)
	ContextActionService:BindAction(CLEAR_TARGET_ACTION, function(_, state, inputObject)
		if ClientCombatUiRules.shouldIgnoreForGuiNavigation(inputObject.UserInputType.Name, GuiService.SelectedObject ~= nil) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then TargetController.clearTarget() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonL3)
	targetAttributeConnection = localPlayer:GetAttributeChangedSignal(TARGET_ATTRIBUTE):Connect(syncConfirmedTarget)
	descendantAddedConnection = workspace.DescendantAdded:Connect(function(descendant: Instance)
		local entityId = localPlayer:GetAttribute(TARGET_ATTRIBUTE)
		if typeof(entityId) == "string" and descendant:IsA("Model") and descendant:GetAttribute("EntityId") == entityId then
			syncConfirmedTarget()
		end
	end)
	syncConfirmedTarget()
end

function TargetController.stop(): ()
	ContextActionService:UnbindAction(TARGET_ACTION)
	ContextActionService:UnbindAction(CLEAR_TARGET_ACTION)
	if inputBeganConnection ~= nil then
		inputBeganConnection:Disconnect()
		inputBeganConnection = nil
	end
	if touchTapConnection ~= nil then
		touchTapConnection:Disconnect()
		touchTapConnection = nil
	end
	if targetAttributeConnection ~= nil then
		targetAttributeConnection:Disconnect()
		targetAttributeConnection = nil
	end
	if descendantAddedConnection ~= nil then
		descendantAddedConnection:Disconnect()
		descendantAddedConnection = nil
	end
	if selectedHighlight ~= nil then
		selectedHighlight:Destroy()
		selectedHighlight = nil
	end
	selectedModel = nil
	onTargetChanged = nil
end

return TargetController
