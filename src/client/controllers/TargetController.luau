--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local TargetController = {}

local localPlayer = Players.LocalPlayer
local targetRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TargetRequest") :: RemoteEvent

local inputBeganConnection: RBXScriptConnection? = nil
local touchTapConnection: RBXScriptConnection? = nil
local selectedHighlight: Highlight? = nil
local onTargetChanged: ((Model?) -> ())? = nil

local function findEntityModel(instance: Instance?): Model?
	local current = instance
	while current ~= nil and current ~= workspace do
		if current:IsA("Model") and typeof(current:GetAttribute("EntityId")) == "string" then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function selectAtScreenPosition(screenPosition: Vector2): ()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local character = localPlayer.Character
	if character ~= nil then
		raycastParams.FilterDescendantsInstances = { character }
	end

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
	local model = if result ~= nil then findEntityModel(result.Instance) else nil
	if model == nil then
		return
	end

	local entityId = model:GetAttribute("EntityId")
	if typeof(entityId) ~= "string" then
		return
	end

	if selectedHighlight ~= nil then
		selectedHighlight:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalTargetHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model
	selectedHighlight = highlight

	targetRequest:FireServer(entityId)
	if onTargetChanged ~= nil then
		onTargetChanged(model)
	end
end

function TargetController.start(targetChanged: (Model?) -> ()): ()
	TargetController.stop()
	onTargetChanged = targetChanged

	inputBeganConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		-- Touch is handled only by TouchTap so one tap cannot issue two requests.
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		selectAtScreenPosition(Vector2.new(input.Position.X, input.Position.Y))
	end)

	touchTapConnection = UserInputService.TouchTap:Connect(function(touchPositions: { Vector2 }, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		local position = touchPositions[1]
		if position ~= nil then
			selectAtScreenPosition(position)
		end
	end)
end

function TargetController.stop(): ()
	if inputBeganConnection ~= nil then
		inputBeganConnection:Disconnect()
		inputBeganConnection = nil
	end
	if touchTapConnection ~= nil then
		touchTapConnection:Disconnect()
		touchTapConnection = nil
	end
	if selectedHighlight ~= nil then
		selectedHighlight:Destroy()
		selectedHighlight = nil
	end
	onTargetChanged = nil
end

return TargetController
