--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local P = require(script.Parent.BlockoutPrimitives)
local VillageAndMeadowsBlockout = require(script.Parent.VillageAndMeadowsBlockout)
local NorthernZonesBlockout = require(script.Parent.NorthernZonesBlockout)
local WorldDressingBlockout = require(script.Parent.WorldDressingBlockout)
local WorldCompositionBlockout = require(script.Parent.WorldCompositionBlockout)

local ROOT_NAME = "LunaWorldPlayableBlockout"
local MANAGED_BY = "PlayableWorldBlockout"
local BOUNDARY_HEIGHT = 320
local BOUNDARY_THICKNESS = 8

local PlayableWorldBlockout = {}

local function createBoundary(root: Instance)
	local bounds = WorldLayout.WorldBounds
	local walls = P.folder(root, "WorldBoundary")
	local centerY = BOUNDARY_HEIGHT / 2

	local function invisibleWall(name: string, size: Vector3, position: Vector3)
		P.part(
			walls,
			name,
			size,
			CFrame.new(position),
			Enum.Material.SmoothPlastic,
			Color3.new(1, 1, 1),
			{
				transparency = 1,
				canCollide = true,
				attributes = { Boundary = true },
			}
		)
	end

	local width = bounds.maxX - bounds.minX
	local depth = bounds.maxZ - bounds.minZ
	local centerX = (bounds.minX + bounds.maxX) / 2
	local centerZ = (bounds.minZ + bounds.maxZ) / 2

	invisibleWall(
		"WestBoundary",
		Vector3.new(BOUNDARY_THICKNESS, BOUNDARY_HEIGHT, depth),
		Vector3.new(bounds.minX + BOUNDARY_THICKNESS / 2, centerY, centerZ)
	)
	invisibleWall(
		"EastBoundary",
		Vector3.new(BOUNDARY_THICKNESS, BOUNDARY_HEIGHT, depth),
		Vector3.new(bounds.maxX - BOUNDARY_THICKNESS / 2, centerY, centerZ)
	)
	invisibleWall(
		"SouthBoundary",
		Vector3.new(width, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS),
		Vector3.new(centerX, centerY, bounds.minZ + BOUNDARY_THICKNESS / 2)
	)
	invisibleWall(
		"NorthBoundary",
		Vector3.new(width, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS),
		Vector3.new(centerX, centerY, bounds.maxZ - BOUNDARY_THICKNESS / 2)
	)
end

local function findManagedRoots(): { Instance }
	local result: { Instance } = {}
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == ROOT_NAME then
			if child:GetAttribute("ManagedBy") ~= MANAGED_BY then
				error(string.format(
					"Refusing to replace Workspace.%s because it is not managed by %s",
					ROOT_NAME,
					MANAGED_BY
				))
			end
			table.insert(result, child)
		end
	end
	return result
end

function PlayableWorldBlockout.rebuild(): (Model, SpawnLocation)
	local oldRoots = findManagedRoots()

	local root = Instance.new("Model")
	root.Name = ROOT_NAME
	root:SetAttribute("ManagedBy", MANAGED_BY)
	root:SetAttribute("TerrainRevision", "terrain-v07")
	root:SetAttribute("Purpose", "OwnerTraversalBlockout")

	local spawn = VillageAndMeadowsBlockout.build(root)
	NorthernZonesBlockout.build(root)
	WorldDressingBlockout.build(root)
	WorldCompositionBlockout.build(root)
	createBoundary(root)

	root.Parent = workspace
	for _, oldRoot in ipairs(oldRoots) do
		oldRoot:Destroy()
	end

	return root, spawn
end

return table.freeze(PlayableWorldBlockout)
