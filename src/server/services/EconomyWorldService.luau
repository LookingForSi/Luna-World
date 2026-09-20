--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local EconomyNetworkService = require(script.Parent.EconomyNetworkService)

local EconomyWorldService = {}
local folder: Folder? = nil
local connections: { RBXScriptConnection } = {}
local ownedInstances: { Instance } = {}

local function point(id: string): Vector3
	for _, poi in WorldLayout.PointsOfInterest do if poi.id == id then return poi.position end end
	error("Missing economy POI " .. id)
end
local function npcModel(name: string): Model?
	local world = Workspace:FindFirstChild("LunaWorldPlayableBlockout")
	if world == nil then return nil end
	local candidate = world:FindFirstChild(name, true)
	if candidate ~= nil and candidate:IsA("Model") then return candidate end
	return nil
end

local function addNameplate(model: Model, roleText: string): ()
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "InteractionNameplate"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Size = UDim2.fromOffset(190, 44)
	billboard.StudsOffset = Vector3.new(0, 2.8, 0)
	billboard.Parent = head
	table.insert(ownedInstances, billboard)

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = roleText
	label.TextColor3 = Color3.fromRGB(238, 226, 190)
	label.TextSize = 15
	label.Parent = billboard

	local highlight = Instance.new("Highlight")
	highlight.Name = "InteractionHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 0.92
	highlight.OutlineTransparency = 0.2
	highlight.OutlineColor = Color3.fromRGB(215, 184, 105)
	highlight.Parent = model
	table.insert(ownedInstances, highlight)
end

local function createPoint(
	parent: Instance,
	name: string,
	position: Vector3,
	actionText: string,
	mode: string,
	npcName: string
): ()
	local target: Instance
	local model = npcModel(npcName)
	if model ~= nil then
		target = model:FindFirstChild("Head") or model:FindFirstChild("Body") or model
		addNameplate(model, if mode == "Craft" then "КУЗНЕЦ" else "ТОРГОВЕЦ")
	else
		local anchor = Instance.new("Part")
		anchor.Name = name
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(4, 6, 4)
		anchor.Position = position + Vector3.new(0, 4, 0)
		anchor.Parent = parent
		target = anchor
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = mode .. "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = if mode == "Craft" then "Кузнец" else "Торговец"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonA
	prompt.Parent = target
	table.insert(ownedInstances, prompt)
	table.insert(connections, prompt.Triggered:Connect(function(player) EconomyNetworkService.openFor(player, mode) end))
end
function EconomyWorldService.start(): ()
	if folder ~= nil then return end
	local created = Instance.new("Folder"); created.Name = "VillageEconomyInteractions"; created.Parent = workspace
	createPoint(created, "MerchantInteraction", point("poi_merchant"), "Поговорить", "Merchant", "MerchantNpc")
	createPoint(created, "BlacksmithInteraction", point("poi_blacksmith"), "Поговорить", "Craft", "BlacksmithNpc")
	folder = created
end
function EconomyWorldService.stop(): ()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for _, instance in ownedInstances do
		if instance.Parent ~= nil then instance:Destroy() end
	end
	table.clear(ownedInstances)
	if folder ~= nil then folder:Destroy(); folder = nil end
end
return EconomyWorldService
