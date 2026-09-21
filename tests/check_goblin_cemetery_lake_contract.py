#!/usr/bin/env python3
"""Static contract for the simplified river-style Goblin/Cemetery lake."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAKE = (ROOT / "src/server/world/GoblinCemeteryLakeTerrain.luau").read_text(encoding="utf-8")
NORTH = (ROOT / "src/server/world/NorthernZonesBlockout.luau").read_text(encoding="utf-8")

for token in (
    "WATER_SURFACE_Y = 76",
    "WATER_DEPTH = 12",
    "BANK_TOP_Y = 80",
    "RESET_BOTTOM_Y = 20",
    "RESET_CLEAR_TOP_Y = 140",
    "SHORE_OVERLAP = 8",
    "RESET_SIZE_X = 1020",
    "RESET_SIZE_Z = 600",
    "LAKE_SECTIONS",
    "WestArm",
    "MiddleWest",
    "MiddleEast",
    "EastBasin",
    "resetLegacyCorridor",
    "fillLakeSection",
    "terrain:FillBlock",
    "Enum.Material.Ground",
    "Enum.Material.Grass",
    "Enum.Material.Air",
    "Enum.Material.Water",
    'LakeGeometry", "RiverStyleOverlappingFillBlocks"',
    'LakeSectionCount", #LAKE_SECTIONS',
):
    assert token in LAKE, f"simple lake contract missing: {token}"

assert 'Purpose", "SwimmableWater"' in NORTH
assert "GoblinCemeteryLakeTerrain.build(lake)" in NORTH

# Explicitly reject the failed experimental architectures.
for forbidden in (
    "ReadVoxels",
    "WriteVoxels",
    "Region3",
    "FillCylinder",
    "fillScanline",
    "SCANLINE_STEP",
    "SCANLINE_OVERLAP",
    "fillContinuousLakePath",
    "fillFlatLakeSlab",
    "carveLakeDisc",
    "prepareGoblinCampBoundaryShelf",
    "shapeGoblinCemeteryLakeHillCliff",
    "WaterRecovery",
    "LakeBedFilled",
):
    assert forbidden not in LAKE, f"obsolete lake architecture still present: {forbidden}"

# Preserve areas: reset corridor is z=2100..2700. Goblin Camp ends near z=2030;
# Old Cemetery content begins around z=2792.
assert "RESET_CENTER = Vector3.new(770, 0, 2400)" in LAKE
assert "RESET_SIZE_Z = 600" in LAKE

# Exactly four authored Water sections; all use the same WATER_SURFACE_Y/depth.
assert LAKE.count('name = "') == 4
assert LAKE.count("Enum.Material.Water") == 1
assert "WATER_SURFACE_Y - WATER_DEPTH / 2" in LAKE

print("Goblin/Cemetery river-style lake contract: PASS")
