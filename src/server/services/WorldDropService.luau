--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local InventoryService = require(script.Parent.InventoryService)

local WorldDropService = {}

local DROP_LIFETIME_SECONDS = 120
local folder: Folder? = nil
local connections: { RBXScriptConnection } = {}

local function dropFolder(): Folder
	if folder ~= nil and folder.Parent ~= nil then return folder end
	local created = Instance.new("Folder")
	created.Name = "WorldDrops"
	created.Parent = Workspace
	folder = created
	return created
end

local function categoryVisual(category: string): (Vector3, Color3, Enum.Material, Enum.PartType)
	if category == "Weapon" then
		return Vector3.new(0.8, 0.8, 5.2), Color3.fromRGB(170, 174, 181), Enum.Material.Metal, Enum.PartType.Block
	elseif category == "Armor" then
		return Vector3.new(2.8, 1.3, 2.3), Color3.fromRGB(105, 112, 122), Enum.Material.Metal, Enum.PartType.Block
	elseif category == "Accessory" then
		return Vector3.new(1.5, 0.8, 1.5), Color3.fromRGB(205, 184, 112), Enum.Material.Metal, Enum.PartType.Cylinder
	elseif category == "Consumable" then
		return Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(153, 88, 94), Enum.Material.Glass, Enum.PartType.Ball
	end
	return Vector3.new(1.8, 1.4, 1.8), Color3.fromRGB(137, 111, 78), Enum.Material.Wood, Enum.PartType.Block
end

local function groundPosition(player: Player): Vector3?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then return nil end

	local forwardPosition = root.Position + root.CFrame.LookVector * 5
	local origin = forwardPosition + Vector3.new(0, 8, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if character ~= nil then { character } else {}
	params.IgnoreWater = false
	local result = Workspace:Raycast(origin, Vector3.new(0, -24, 0), params)
	if result ~= nil then
		return result.Position + Vector3.new(0, 1.2, 0)
	end
	return forwardPosition
end

local function addLabel(part: BasePart, text: string): ()
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DropNameplate"
	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Size = UDim2.fromOffset(190, 38)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
	label.BackgroundTransparency = 0.22
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = Color3.fromRGB(236, 232, 214)
	label.TextSize = 13
	label.TextWrapped = true
	label.Parent = billboard
end

function WorldDropService.spawnForPlayer(player: Player, itemId: string, quantity: number): boolean
	local definition = ItemDefinitions[itemId]
	if definition == nil or quantity <= 0 then return false end
	local position = groundPosition(player)
	if position == nil then return false end

	local model = Instance.new("Model")
	model.Name = "Drop_" .. HttpService:GenerateGUID(false)
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Quantity", quantity)
	model.Parent = dropFolder()

	local size, color, material, shape = categoryVisual(definition.category)
	local part = Instance.new("Part")
	part.Name = "Visual"
	part.Size = size
	part.Color = color
	part.Material = material
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CFrame = CFrame.new(position) * if definition.category == "Weapon"
		then CFrame.Angles(0, 0, math.rad(65))
		else CFrame.new()
	part.Parent = model
	model.PrimaryPart = part

	local highlight = Instance.new("Highlight")
	highlight.Name = "DropHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 0.9
	highlight.OutlineTransparency = 0.25
	highlight.OutlineColor = color
	highlight.Parent = model

	local label = definition.displayName
	if quantity > 1 then label ..= " ×" .. tostring(quantity) end
	addLabel(part, label)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Подобрать"
	prompt.ObjectText = definition.displayName
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = part

	local claimed = false
	table.insert(connections, prompt.Triggered:Connect(function(picker: Player)
		if claimed or model.Parent == nil then return end
		claimed = true
		local ok = InventoryService.grantItem(picker, itemId, quantity)
		if ok then
			model:Destroy()
		else
			claimed = false
		end
	end))

	task.delay(DROP_LIFETIME_SECONDS, function()
		if model.Parent ~= nil then model:Destroy() end
	end)
	return true
end

function WorldDropService.start(): ()
	dropFolder()
end

function WorldDropService.stop(): ()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
end

return WorldDropService
