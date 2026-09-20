--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local EconomyNetworkService = require(script.Parent.EconomyNetworkService)

local EconomyWorldService = {}
local folder: Folder? = nil
local connections: { RBXScriptConnection } = {}

local function point(id: string): Vector3
	for _, poi in WorldLayout.PointsOfInterest do if poi.id == id then return poi.position end end
	error("Missing economy POI " .. id)
end
local function createPoint(parent: Instance, name: string, position: Vector3, actionText: string, mode: string): ()
	local anchor = Instance.new("Part")
	anchor.Name = name; anchor.Anchored = true; anchor.CanCollide = false; anchor.Transparency = 1
	anchor.Size = Vector3.new(4, 6, 4); anchor.Position = position + Vector3.new(0, 4, 0); anchor.Parent = parent
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = mode .. "Prompt"; prompt.ActionText = actionText; prompt.ObjectText = if mode == "Craft" then "Кузнец" else "Торговец"
	prompt.MaxActivationDistance = 18; prompt.RequiresLineOfSight = false; prompt.HoldDuration = 0; prompt.Parent = anchor
	table.insert(connections, prompt.Triggered:Connect(function(player) EconomyNetworkService.openFor(player, mode) end))
end
function EconomyWorldService.start(): ()
	if folder ~= nil then return end
	local created = Instance.new("Folder"); created.Name = "VillageEconomyInteractions"; created.Parent = workspace
	createPoint(created, "MerchantInteraction", point("poi_merchant"), "Торговать", "Merchant")
	createPoint(created, "BlacksmithInteraction", point("poi_blacksmith"), "Ковать", "Craft")
	folder = created
end
function EconomyWorldService.stop(): ()
	for _, connection in connections do connection:Disconnect() end; table.clear(connections)
	if folder ~= nil then folder:Destroy(); folder = nil end
end
return EconomyWorldService
