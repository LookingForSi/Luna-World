--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NpcDefinitions = require(ReplicatedStorage.Shared.definitions.NpcDefinitions)
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local Grounding = require(script.Parent.Parent.world.TerrainGrounding)
local QuestService = require(script.Parent.QuestService)

local service = {}
local folder: Folder? = nil
local connections: { RBXScriptConnection } = {}

local function poiPosition(id: string): Vector3
	for _, point in WorldLayout.PointsOfInterest do
		if point.id == id then return point.position end
	end
	error("Missing NPC POI " .. id)
end

local function findExistingModel(definition: any): Model?
	local world = workspace:FindFirstChild("LunaWorldPlayableBlockout")
	if world == nil then return nil end
	local existing = world:FindFirstChild(definition.modelName, true)
	if existing ~= nil and existing:IsA("Model") then
		return existing
	end
	return nil
end

local function makeFallbackModel(parent: Instance, definition: any): Model
	local authored = poiPosition(definition.poiId) + (definition.positionOffset or Vector3.zero)
	local ground = Grounding.surfaceAt(authored)

	local model = Instance.new("Model")
	model.Name = definition.modelName

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = Vector3.new(3, 5, 2)
	body.Color = Color3.fromRGB(103, 139, 151)
	body.CFrame = CFrame.new(ground + Vector3.new(0, 3.5, 0))
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.CanCollide = false
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.4, 2.4, 2.4)
	head.Color = Color3.fromRGB(220, 214, 198)
	head.CFrame = CFrame.new(ground + Vector3.new(0, 7, 0))
	head.Parent = model

	model.PrimaryPart = body
	model.Parent = parent
	return model
end

local function ensureNameplate(target: BasePart, displayName: string): ()
	if target:FindFirstChild("NpcNameplate") ~= nil then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NpcNameplate"
	billboard.Adornee = target
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Size = UDim2.fromOffset(180, 26)
	billboard.StudsOffset = Vector3.new(0, 2.7, 0)
	billboard.Parent = target

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = displayName
	label.TextColor3 = Color3.fromRGB(235, 233, 219)
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	label.TextStrokeTransparency = 0.3
	label.TextSize = 14
	label.Parent = billboard
end

local function attachQuestNpc(model: Model, npcId: string, definition: any): ()
	model:SetAttribute("NpcId", npcId)
	model:SetAttribute("InteractiveNpc", true)

	local target = model:FindFirstChild("Head") or model:FindFirstChild("Body") or model.PrimaryPart
	if target == nil or not target:IsA("BasePart") then return end

	ensureNameplate(target, definition.displayName)

	local oldPrompt = target:FindFirstChild("TalkPrompt")
	if oldPrompt ~= nil then oldPrompt:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Поговорить"
	prompt.ObjectText = definition.displayName
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	prompt.Parent = target

	table.insert(connections, prompt.Triggered:Connect(function(player)
		QuestService.openNpc(player, npcId)
	end))
end

function service.start(): ()
	if folder ~= nil then return end

	folder = Instance.new("Folder")
	folder.Name = "NpcInteractions"
	folder.Parent = workspace

	for npcId, definition in NpcDefinitions do
		if definition.economy then continue end

		local model = findExistingModel(definition)
		if model == nil then
			model = makeFallbackModel(folder, definition)
		end
		attachQuestNpc(model, npcId, definition)
	end
end

function service.stop(): ()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end

return service
