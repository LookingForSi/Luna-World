#!/usr/bin/env python3
"""Static geometry and preservation contract for the rebuilt corridor lake."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAKE_PATH = ROOT / "src/server/world/GoblinCemeteryLakeTerrain.luau"
NORTH_PATH = ROOT / "src/server/world/NorthernZonesBlockout.luau"

lake = LAKE_PATH.read_text(encoding="utf-8")
north = NORTH_PATH.read_text(encoding="utf-8")

assert "local WATER_DEPTH = 14" in lake
assert 'Purpose", "SwimmableWater"' in north
assert "GoblinCemeteryLakeTerrain.build(lake, surfaceReference)" in north
assert "CFrame.new(centerX" in lake
assert "CFrame.Angles" not in lake
assert "FillCylinder" not in lake
assert "waterSurfaceY - WATER_DEPTH / 2" in lake
assert "waterWidth = clearWidth + WATER_SHORE_OVERLAP * 2" in lake
assert "BED_THICKNESS + BED_WATER_OVERLAP" in lake
assert lake.index("Enum.Material.Mud") < lake.index("Enum.Material.Water")

for obsolete in (
    "fillContinuousLakePath",
    "fillFlatLakeSlab",
    "carveLakeDisc",
    "prepareGoblinCampBoundaryShelf",
    "shapeGoblinCemeteryLakeHillCliff",
    "ExtendsToWorldEdge",
    "WaterRecovery",
):
    assert obsolete not in lake and obsolete not in north

points = [
    (float(x), float(z))
    for x, z in re.findall(r"Vector2\.new\(([-\d.]+), ([-\d.]+)\)", lake)
]
assert len(points) == 15
assert min(x for x, _ in points) >= 300
assert max(x for x, _ in points) + 6 <= 1300

# Goblin Camp: center (560, 1920), half extents (137, 110), plus 50-stud
# preservation margin. Cemetery authored content begins at z=2792; keep 50 studs.
assert min(z for _, z in points) - 6 >= 1920 + 110 + 50
assert max(z for _, z in points) + 6 <= 2792 - 50

print("Goblin/Cemetery lake rebuild contract: PASS")
