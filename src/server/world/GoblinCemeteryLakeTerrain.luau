--!strict

local Workspace = game:GetService("Workspace")

local GoblinCemeteryLakeTerrain = {}

-- Keep lake water intentionally boring. The accepted river already proves that
-- a few overlapping Terrain:FillBlock(..., Water) volumes at one surface level
-- behave well in Roblox. The lake now follows the same rule instead of owning a
-- separate voxel/rasterization system.
local WATER_SURFACE_Y = 76
local WATER_DEPTH = 12
local WATER_BOTTOM_Y = WATER_SURFACE_Y - WATER_DEPTH
local BANK_TOP_Y = 80
local RESET_BOTTOM_Y = 20
local RESET_CLEAR_TOP_Y = 140
local SHORE_OVERLAP = 8

-- Hard reset envelope for every experimental lake revision made during dev0.3.
-- It starts south of the Goblin Camp preserve area and stops north of Old
-- Cemetery, so the camp/cemetery themselves are never rebuilt by this pass.
local RESET_CENTER = Vector3.new(770, 0, 2400)
local RESET_SIZE_X = 1020 -- X: 260 .. 1280
local RESET_SIZE_Z = 600  -- Z: 2100 .. 2700

-- Four simple overlapping basins approximate the owner sketch:
-- narrow west arm -> longer middle -> broad east basin.
-- All are axis-aligned, share one surface level and overlap generously.
local LAKE_SECTIONS = {
	{ name = "WestArm", centerX = 430, centerZ = 2310, sizeX = 280, sizeZ = 150 },
	{ name = "MiddleWest", centerX = 625, centerZ = 2330, sizeX = 260, sizeZ = 190 },
	{ name = "MiddleEast", centerX = 825, centerZ = 2350, sizeX = 280, sizeZ = 220 },
	{ name = "EastBasin", centerX = 1060, centerZ = 2360, sizeX = 380, sizeZ = 360 },
}

local function resetLegacyCorridor(terrain: Terrain)
	-- 1) Rebuild one plain solid corridor so no Water/Air/Mud from any previous
	--    lake experiment survives underneath or beside the new lake.
	local baseHeight = BANK_TOP_Y - RESET_BOTTOM_Y
	terrain:FillBlock(
		CFrame.new(RESET_CENTER.X, RESET_BOTTOM_Y + baseHeight / 2, RESET_CENTER.Z),
		Vector3.new(RESET_SIZE_X, baseHeight, RESET_SIZE_Z),
		Enum.Material.Ground
	)

	-- 2) Remove every old vertical water slab/terrain overhang above the bank.
	local clearHeight = RESET_CLEAR_TOP_Y - BANK_TOP_Y
	terrain:FillBlock(
		CFrame.new(RESET_CENTER.X, BANK_TOP_Y + clearHeight / 2, RESET_CENTER.Z),
		Vector3.new(RESET_SIZE_X, clearHeight, RESET_SIZE_Z),
		Enum.Material.Air
	)

	-- 3) Give the rebuilt corridor a simple grass cap. The lake carve below will
	--    remove only the sections that are actually water.
	terrain:FillBlock(
		CFrame.new(RESET_CENTER.X, BANK_TOP_Y - 2, RESET_CENTER.Z),
		Vector3.new(RESET_SIZE_X, 4, RESET_SIZE_Z),
		Enum.Material.Grass
	)
end

local function fillLakeSection(terrain: Terrain, section)
	-- Remove land only above the waterline and only inside the visible section.
	-- There is no deep Air bowl: solid terrain remains immediately below Y=64.
	local clearHeight = RESET_CLEAR_TOP_Y - WATER_SURFACE_Y
	terrain:FillBlock(
		CFrame.new(section.centerX, WATER_SURFACE_Y + clearHeight / 2, section.centerZ),
		Vector3.new(section.sizeX, clearHeight, section.sizeZ),
		Enum.Material.Air
	)

	-- Slightly wider Water is intentional: it runs a few studs underneath the
	-- untouched bank, preventing a dry crack at voxelized shore edges.
	terrain:FillBlock(
		CFrame.new(section.centerX, WATER_SURFACE_Y - WATER_DEPTH / 2, section.centerZ),
		Vector3.new(
			section.sizeX + SHORE_OVERLAP * 2,
			WATER_DEPTH,
			section.sizeZ + SHORE_OVERLAP * 2
		),
		Enum.Material.Water
	)
end

function GoblinCemeteryLakeTerrain.build(lake: Model)
	local terrain = Workspace.Terrain

	resetLegacyCorridor(terrain)

	for _, section in ipairs(LAKE_SECTIONS) do
		fillLakeSection(terrain, section)
	end

	lake:SetAttribute("WaterSurfaceY", WATER_SURFACE_Y)
	lake:SetAttribute("WaterDepth", WATER_DEPTH)
	lake:SetAttribute("LakeGeometry", "RiverStyleOverlappingFillBlocks")
	lake:SetAttribute("LakeSectionCount", #LAKE_SECTIONS)
	lake:SetAttribute("ResetLegacyCorridor", true)
	lake:SetAttribute("ContainedWithinWorldBounds", true)
end

return table.freeze(GoblinCemeteryLakeTerrain)
