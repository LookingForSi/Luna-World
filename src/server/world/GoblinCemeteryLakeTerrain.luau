--!strict

local Workspace = game:GetService("Workspace")

local GoblinCemeteryLakeTerrain = {}

local WATER_SURFACE_Y = 74
local WATER_DEPTH = 14
local BED_THICKNESS = 6
local BED_WATER_OVERLAP = 2
local WATER_SHORE_OVERLAP = 6
local SCANLINE_STEP = 12
local SCANLINE_OVERLAP = 2
local AIR_CLEARANCE_HEIGHT = 52
local LEGACY_RESET_BOTTOM_Y = 26
local RESTORED_BANK_TOP_Y = 82

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

-- This is a one-way terrain migration boundary, not the former lake shape. It
-- encloses every legacy lobe and deep excavation while remaining outside all
-- three hard-preserve areas. Re-filling it makes rebuilds deterministic even
-- when Studio starts with terrain-v10 already baked into the place.
local LEGACY_RESET_OUTLINE = {
	Vector2.new(290, 2110),
	Vector2.new(760, 2110),
	Vector2.new(1010, 2210),
	Vector2.new(1020, 2635),
	Vector2.new(850, 2705),
	Vector2.new(450, 2705),
	Vector2.new(285, 2540),
}

local function intersectionsAt(outline: { Vector2 }, z: number): { number }
	local intersections = {}
	for index, first in ipairs(outline) do
		local second = outline[index % #outline + 1]
		local crosses = (first.Y <= z and second.Y > z) or (second.Y <= z and first.Y > z)
		if crosses then
			local alpha = (z - first.Y) / (second.Y - first.Y)
			table.insert(intersections, first.X + (second.X - first.X) * alpha)
		end
	end
	table.sort(intersections)
	return intersections
end

local function zBounds(outline: { Vector2 }): (number, number)
	local minZ = math.huge
	local maxZ = -math.huge
	for _, point in ipairs(outline) do
		minZ = math.min(minZ, point.Y)
		maxZ = math.max(maxZ, point.Y)
	end
	return minZ, maxZ
end

local function resetLegacyCorridor(terrain: Terrain)
	local minZ, maxZ = zBounds(LEGACY_RESET_OUTLINE)
	local height = RESTORED_BANK_TOP_Y - LEGACY_RESET_BOTTOM_Y
	for z = minZ + SCANLINE_STEP / 2, maxZ - SCANLINE_STEP / 2, SCANLINE_STEP do
		local intersections = intersectionsAt(LEGACY_RESET_OUTLINE, z)
		for index = 1, #intersections - 1, 2 do
			local minX = intersections[index]
			local maxX = intersections[index + 1]
			terrain:FillBlock(
				CFrame.new((minX + maxX) / 2, LEGACY_RESET_BOTTOM_Y + height / 2, z),
				Vector3.new(maxX - minX, height, SCANLINE_STEP + SCANLINE_OVERLAP),
				Enum.Material.Ground
			)
		end
	end
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

function GoblinCemeteryLakeTerrain.build(lake: Model)
	local terrain = Workspace.Terrain
	resetLegacyCorridor(terrain)
	local minZ, maxZ = zBounds(LAKE_OUTLINE)

	for z = minZ + SCANLINE_STEP / 2, maxZ - SCANLINE_STEP / 2, SCANLINE_STEP do
		local intersections = intersectionsAt(LAKE_OUTLINE, z)
		for index = 1, #intersections - 1, 2 do
			fillScanline(terrain, z, intersections[index], intersections[index + 1], WATER_SURFACE_Y)
		end
	end

	lake:SetAttribute("WaterSurfaceY", WATER_SURFACE_Y)
	lake:SetAttribute("WaterDepth", WATER_DEPTH)
	lake:SetAttribute("LakeBedMaterial", "Mud")
	lake:SetAttribute("LakeGeometry", "AxisAlignedPolygonScanlines")
	lake:SetAttribute("ContainedWithinWorldBounds", true)
end

return table.freeze(GoblinCemeteryLakeTerrain)
