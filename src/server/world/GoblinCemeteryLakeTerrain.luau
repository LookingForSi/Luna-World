--!strict

local Workspace = game:GetService("Workspace")

local Grounding = require(script.Parent.TerrainGrounding)

local GoblinCemeteryLakeTerrain = {}

local WATER_DEPTH = 14
local WATER_SURFACE_DROP = 8
local BED_THICKNESS = 6
local BED_WATER_OVERLAP = 2
local WATER_SHORE_OVERLAP = 6
local SCANLINE_STEP = 12
local SCANLINE_OVERLAP = 2
local AIR_CLEARANCE_HEIGHT = 52

-- World-space outline. It deliberately stays outside the Goblin Camp preserve
-- rectangle, the cemetery encounter floor, Moonfall Road, and WorldBounds.
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

local function intersectionsAt(z: number): { number }
	local intersections = {}
	for index, first in ipairs(LAKE_OUTLINE) do
		local second = LAKE_OUTLINE[index % #LAKE_OUTLINE + 1]
		local crosses = (first.Y <= z and second.Y > z) or (second.Y <= z and first.Y > z)
		if crosses then
			local alpha = (z - first.Y) / (second.Y - first.Y)
			table.insert(intersections, first.X + (second.X - first.X) * alpha)
		end
	end
	table.sort(intersections)
	return intersections
end

local function fillScanline(terrain: Terrain, z: number, minX: number, maxX: number, waterSurfaceY: number)
	local clearWidth = maxX - minX
	local waterWidth = clearWidth + WATER_SHORE_OVERLAP * 2
	local centerX = (minX + maxX) / 2
	local waterBottomY = waterSurfaceY - WATER_DEPTH
	local stripDepth = SCANLINE_STEP + SCANLINE_OVERLAP

	-- Air is restricted to the authored footprint. Water extends beneath the
	-- untouched bank on both sides, so clearing can never form a dry trench.
	terrain:FillBlock(
		CFrame.new(centerX, waterBottomY + (WATER_DEPTH + AIR_CLEARANCE_HEIGHT) / 2, z),
		Vector3.new(clearWidth, WATER_DEPTH + AIR_CLEARANCE_HEIGHT, stripDepth),
		Enum.Material.Air
	)

	-- The bed meets the water volume with a deliberate overlap. Fill it before
	-- Water so the final material at the seam remains swimmable Water.
	terrain:FillBlock(
		CFrame.new(centerX, waterBottomY - (BED_THICKNESS - BED_WATER_OVERLAP) / 2, z),
		Vector3.new(waterWidth, BED_THICKNESS + BED_WATER_OVERLAP, stripDepth),
		Enum.Material.Mud
	)
	terrain:FillBlock(
		CFrame.new(centerX, waterSurfaceY - WATER_DEPTH / 2, z),
		Vector3.new(waterWidth, WATER_DEPTH, stripDepth),
		Enum.Material.Water
	)
end

function GoblinCemeteryLakeTerrain.build(lake: Model, surfaceReference: Vector3)
	local terrain = Workspace.Terrain
	local waterSurfaceY = Grounding.surfaceAt(surfaceReference).Y - WATER_SURFACE_DROP
	local minZ = math.huge
	local maxZ = -math.huge
	for _, point in ipairs(LAKE_OUTLINE) do
		minZ = math.min(minZ, point.Y)
		maxZ = math.max(maxZ, point.Y)
	end

	for z = minZ + SCANLINE_STEP / 2, maxZ - SCANLINE_STEP / 2, SCANLINE_STEP do
		local intersections = intersectionsAt(z)
		for index = 1, #intersections - 1, 2 do
			fillScanline(terrain, z, intersections[index], intersections[index + 1], waterSurfaceY)
		end
	end

	lake:SetAttribute("WaterSurfaceY", waterSurfaceY)
	lake:SetAttribute("WaterDepth", WATER_DEPTH)
	lake:SetAttribute("LakeBedMaterial", "Mud")
	lake:SetAttribute("LakeGeometry", "AxisAlignedPolygonScanlines")
	lake:SetAttribute("ContainedWithinWorldBounds", true)
end

return table.freeze(GoblinCemeteryLakeTerrain)
