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
assert "GoblinCemeteryLakeTerrain.build(lake)" in north
assert "CFrame.new(centerX" in lake
assert "CFrame.Angles" not in lake
assert "FillCylinder" not in lake
assert "waterSurfaceY - WATER_DEPTH / 2" in lake
assert "waterWidth = clearWidth + WATER_SHORE_OVERLAP * 2" in lake
assert "BED_THICKNESS + BED_WATER_OVERLAP" in lake
assert lake.index("Enum.Material.Mud") < lake.index("Enum.Material.Water")
assert "local WATER_SURFACE_Y = 74" in lake
assert "local LEGACY_RESET_BOTTOM_Y = 26" in lake
assert "local RESTORED_BANK_TOP_Y = 82" in lake
assert "resetLegacyCorridor(terrain)" in lake
assert lake.index("resetLegacyCorridor(terrain)") < lake.index("zBounds(LAKE_OUTLINE)")

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

all_points = [
    (float(x), float(z))
    for x, z in re.findall(r"Vector2\.new\(([-\d.]+), ([-\d.]+)\)", lake)
]
points = all_points[:15]
assert len(points) == 15
assert min(x for x, _ in points) >= 300
assert max(x for x, _ in points) + 6 <= 1300

# Goblin Camp: center (560, 1920), half extents (137, 110), plus 50-stud
# preservation margin. Cemetery authored content begins at z=2792; keep 50 studs.
assert min(z for _, z in points) - 6 >= 1920 + 110 + 50
assert max(z for _, z in points) + 6 <= 2792 - 50

legacy_reset = all_points[15:]
assert len(legacy_reset) == 7
assert min(z for _, z in legacy_reset) >= 1920 + 110 + 50
assert max(z for _, z in legacy_reset) <= 2792 - 50
assert min(x for x, _ in legacy_reset) > 22  # Moonfall Road width around X=0.
assert max(x for x, _ in legacy_reset) <= 1300

print("Goblin/Cemetery lake rebuild contract: PASS")
