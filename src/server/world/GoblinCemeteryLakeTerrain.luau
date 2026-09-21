--!strict

local Workspace = game:GetService("Workspace")

local GoblinCemeteryLakeTerrain = {}

-- Roblox Terrain is a 4x4x4-stud voxel grid. The lake is authored directly on
-- that grid and committed with one WriteVoxels call so there are no independently
-- voxelized Water blocks/scanlines that can render as internal slabs.
local VOXEL_RESOLUTION = 4
local WATER_SURFACE_Y = 76
local WATER_DEPTH = 12
local WATER_BOTTOM_Y = WATER_SURFACE_Y - WATER_DEPTH
local BED_THICKNESS = 4
local CLEAR_TOP_Y = 132

local LEGACY_RESET_BOTTOM_Y = 24
local RESTORED_BANK_TOP_Y = 84

-- World-space outline requested by the owner. It stays outside the Goblin Camp
-- preserve rectangle, Old Cemetery authored content, Moonfall Road and bounds.
local LAKE_OUTLINE = {
	Vector2.new(300, 2220),
	Vector2.new(430, 2160),
	Vector2.new(650, 2180),
	Vector2.new(850, 2190),
	Vector2.new(1030, 2140),
	Vector2.new(1170, 2200),
	Vector2.new(1240, 2320),
	Vector2.new(1220, 2440),
	Vector2.new(1120, 2530),
	Vector2.new(990, 2570),
	Vector2.new(850, 2510),
	Vector2.new(730, 2440),
	Vector2.new(520, 2450),
	Vector2.new(380, 2390),
	Vector2.new(300, 2300),
}

-- Migration envelope only: restore terrain damaged by earlier lake experiments
-- before carving the final polygon. It does not define the new shoreline.
local LEGACY_RESET_OUTLINE = {
	Vector2.new(290, 2110),
	Vector2.new(760, 2110),
	Vector2.new(1010, 2210),
	Vector2.new(1020, 2635),
	Vector2.new(850, 2705),
	Vector2.new(450, 2705),
	Vector2.new(285, 2540),
}

local function containsPoint(outline: { Vector2 }, x: number, z: number): boolean
	local inside = false
	local previous = outline[#outline]

	for _, current in ipairs(outline) do
		local crosses = (current.Y > z) ~= (previous.Y > z)
		if crosses then
			local edgeX = (previous.X - current.X) * (z - current.Y) / (previous.Y - current.Y) + current.X
			if x < edgeX then
				inside = not inside
			end
		end
		previous = current
	end

	return inside
end

local function boundsOf(outlines: { { Vector2 } }): (number, number, number, number)
	local minX = math.huge
	local maxX = -math.huge
	local minZ = math.huge
	local maxZ = -math.huge

	for _, outline in ipairs(outlines) do
		for _, point in ipairs(outline) do
			minX = math.min(minX, point.X)
			maxX = math.max(maxX, point.X)
			minZ = math.min(minZ, point.Y)
			maxZ = math.max(maxZ, point.Y)
		end
	end

	return minX, maxX, minZ, maxZ
end

local function voxelCenter(region: Region3, xIndex: number, yIndex: number, zIndex: number): Vector3
	local minCorner = region.CFrame.Position - region.Size / 2
	return minCorner + Vector3.new(
		(xIndex - 0.5) * VOXEL_RESOLUTION,
		(yIndex - 0.5) * VOXEL_RESOLUTION,
		(zIndex - 0.5) * VOXEL_RESOLUTION
	)
end

function GoblinCemeteryLakeTerrain.build(lake: Model)
	local terrain = Workspace.Terrain
	local minX, maxX, minZ, maxZ = boundsOf({ LAKE_OUTLINE, LEGACY_RESET_OUTLINE })

	-- Work on one grid-aligned terrain region. Read first so everything outside
	-- the migration/lake masks remains byte-for-byte the current terrain.
	local region = Region3.new(
		Vector3.new(minX - VOXEL_RESOLUTION, LEGACY_RESET_BOTTOM_Y, minZ - VOXEL_RESOLUTION),
		Vector3.new(maxX + VOXEL_RESOLUTION, CLEAR_TOP_Y, maxZ + VOXEL_RESOLUTION)
	):ExpandToGrid(VOXEL_RESOLUTION)

	local materials, occupancy = terrain:ReadVoxels(region, VOXEL_RESOLUTION)

	for xIndex = 1, #materials do
		for yIndex = 1, #materials[xIndex] do
			for zIndex = 1, #materials[xIndex][yIndex] do
				local center = voxelCenter(region, xIndex, yIndex, zIndex)
				local inReset = containsPoint(LEGACY_RESET_OUTLINE, center.X, center.Z)
				local inLake = containsPoint(LAKE_OUTLINE, center.X, center.Z)

				-- First erase the accumulated terrain damage from prior lake
				-- experiments, but only inside the explicit migration envelope.
				if inReset and center.Y >= LEGACY_RESET_BOTTOM_Y and center.Y < RESTORED_BANK_TOP_Y then
					materials[xIndex][yIndex][zIndex] = Enum.Material.Ground
					occupancy[xIndex][yIndex][zIndex] = 1
				end

				if inLake then
					if center.Y >= WATER_SURFACE_Y and center.Y < CLEAR_TOP_Y then
						-- Clear only the exact lake footprint above the water.
						materials[xIndex][yIndex][zIndex] = Enum.Material.Air
						occupancy[xIndex][yIndex][zIndex] = 0
					elseif center.Y >= WATER_BOTTOM_Y and center.Y < WATER_SURFACE_Y then
						-- Exactly three full 4-stud Water voxels: one continuous
						-- body, one surface level, no per-strip rasterization.
						materials[xIndex][yIndex][zIndex] = Enum.Material.Water
						occupancy[xIndex][yIndex][zIndex] = 1
					elseif center.Y >= WATER_BOTTOM_Y - BED_THICKNESS and center.Y < WATER_BOTTOM_Y then
						-- Solid bed directly touches the Water; there is no void.
						materials[xIndex][yIndex][zIndex] = Enum.Material.Mud
						occupancy[xIndex][yIndex][zIndex] = 1
					end
				end
			end
		end
	end

	terrain:WriteVoxels(region, VOXEL_RESOLUTION, materials, occupancy)

	lake:SetAttribute("WaterSurfaceY", WATER_SURFACE_Y)
	lake:SetAttribute("WaterDepth", WATER_DEPTH)
	lake:SetAttribute("LakeBedMaterial", "Mud")
	lake:SetAttribute("LakeGeometry", "SingleRegionPolygonVoxels")
	lake:SetAttribute("VoxelResolution", VOXEL_RESOLUTION)
	lake:SetAttribute("ContainedWithinWorldBounds", true)
end

return table.freeze(GoblinCemeteryLakeTerrain)
