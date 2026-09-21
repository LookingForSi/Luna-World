#!/usr/bin/env python3
"""Static geometry and preservation contract for the rebuilt corridor lake."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAKE_PATH = ROOT / "src/server/world/GoblinCemeteryLakeTerrain.luau"
NORTH_PATH = ROOT / "src/server/world/NorthernZonesBlockout.luau"

lake = LAKE_PATH.read_text(encoding="utf-8")
north = NORTH_PATH.read_text(encoding="utf-8")

for token in (
    "local VOXEL_RESOLUTION = 4",
    "local WATER_SURFACE_Y = 76",
    "local WATER_DEPTH = 12",
    "local BED_THICKNESS = 4",
    "terrain:ReadVoxels(region, VOXEL_RESOLUTION)",
    "terrain:WriteVoxels(region, VOXEL_RESOLUTION, materials, occupancy)",
    "Region3.new(",
    ":ExpandToGrid(VOXEL_RESOLUTION)",
    "containsPoint(LAKE_OUTLINE",
    "containsPoint(LEGACY_RESET_OUTLINE",
    "Enum.Material.Air",
    "Enum.Material.Mud",
    "Enum.Material.Water",
    'LakeGeometry", "SingleRegionPolygonVoxels"',
    'ContainedWithinWorldBounds", true',
):
    assert token in lake, f"single-region lake contract missing: {token}"

assert 'Purpose", "SwimmableWater"' in north
assert "GoblinCemeteryLakeTerrain.build(lake)" in north

# Water is written as one voxel volume; no independently rasterized strips/lobes.
for forbidden in (
    "fillScanline",
    "SCANLINE_STEP",
    "SCANLINE_OVERLAP",
    "WATER_SHORE_OVERLAP",
    "FillCylinder",
    "terrain:FillBlock",
    "CFrame.Angles",
    "fillContinuousLakePath",
    "fillFlatLakeSlab",
    "carveLakeDisc",
    "prepareGoblinCampBoundaryShelf",
    "shapeGoblinCemeteryLakeHillCliff",
    "ExtendsToWorldEdge",
    "WaterRecovery",
):
    assert forbidden not in lake, f"obsolete segmented lake generator still present: {forbidden}"

assert lake.index("terrain:ReadVoxels") < lake.index("terrain:WriteVoxels")
assert lake.index("Enum.Material.Mud") < lake.index("Enum.Material.Water")

all_points = [
    (float(x), float(z))
    for x, z in re.findall(r"Vector2\.new\(([-\d.]+), ([-\d.]+)\)", lake)
]
points = all_points[:15]
assert len(points) == 15
assert min(x for x, _ in points) >= 300
assert max(x for x, _ in points) <= 1240

# Goblin Camp: center (560, 1920), half extents (137, 110), plus 50-stud
# preservation margin. Cemetery authored content begins at z=2792; keep 50 studs.
assert min(z for _, z in points) >= 1920 + 110 + 50
assert max(z for _, z in points) <= 2792 - 50

legacy_reset = all_points[15:]
assert len(legacy_reset) == 7
assert min(z for _, z in legacy_reset) >= 1920 + 110 + 50
assert max(z for _, z in legacy_reset) <= 2792 - 50
assert min(x for x, _ in legacy_reset) > 22
assert max(x for x, _ in legacy_reset) <= 1300

print("Goblin/Cemetery single-region voxel lake contract: PASS")
