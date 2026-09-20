#!/usr/bin/env python3
"""Static contract for stock swimming in Luna World Terrain water."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

movement = (ROOT / "src/client/controllers/MovementController.luau").read_text(encoding="utf-8")
recovery = (ROOT / "src/server/world/TraversalRecovery.luau").read_text(encoding="utf-8")
south = (ROOT / "src/server/world/VillageAndMeadowsBlockout.luau").read_text(encoding="utf-8")
north = (ROOT / "src/server/world/NorthernZonesBlockout.luau").read_text(encoding="utf-8")
presentation = (ROOT / "src/client/world-preview/ZonePresentation.client.luau").read_text(encoding="utf-8")

for token in (
    "Enum.HumanoidStateType.Swimming",
    "Enum.ContextActionResult.Pass",
    "Enum.ContextActionResult.Sink",
    "humanoid.StateChanged:Connect",
    "return swimming",
):
    if token not in movement:
        raise AssertionError(f"movement swimming contract missing: {token}")

for forbidden in (
    "SetStateEnabled(Enum.HumanoidStateType.Jumping, false)",
    "JumpPower = 0",
    "JumpHeight = 0",
):
    if forbidden in movement:
        raise AssertionError(f"movement controller blocks stock swim controls: {forbidden}")

if "Enum.Material.Water" not in south:
    raise AssertionError("river must use real Terrain water")
if "Enum.Material.Water" not in north:
    raise AssertionError("lake must use real Terrain water")

for source_name, source in (("river", south), ("recovery", recovery)):
    if "WaterRecovery" in source:
        raise AssertionError(f"{source_name} still contains a hidden water teleport hazard")

if 'Purpose", "SwimmableWater"' not in north:
    raise AssertionError("lake must be explicitly marked as swimmable")

if "WaterRecovery" in north:
    raise AssertionError("lake must not contain a hidden water teleport hazard")

for token in (
    "LAKE_WATER_DEPTH = 30",
    "LAKE_BASIN_CLEAR_DEPTH = 40",
    "LAKE_CLEAR_MARGIN = 34",
    'DeepBasinExcavated", true',
    "clearBottomY = waterSurfaceY + 1",
    "shapeGoblinCemeteryLakeHillCliff",
    'HillBankCliff", true',
):
    if token not in north:
        raise AssertionError(f"accepted 21:20 lake contract missing: {token}")

for lake_forbidden in (
    "prepareGoblinCampBoundaryShelf",
    "fillFlatLakeSlab",
    "fillContinuousLakePath",
    "carveLakeDisc",
    "LakeBedFilled",
    "ContainedWithinWorldBounds",
    "ExtendsToWorldEdge",
):
    if lake_forbidden in north:
        raise AssertionError(f"post-21:20 lake experiment still present: {lake_forbidden}")

for forbidden in (
    "fellIntoRiver",
    "isInsideWaterHazard",
    "or swimming",
):
    if forbidden in recovery:
        raise AssertionError(f"traversal recovery still teleports swimmers: {forbidden}")

if "humanoid:GetState() == Enum.HumanoidStateType.Swimming" not in recovery:
    raise AssertionError("swimming must be excluded from last-safe grounded samples")

for forbidden in (
    "LunaWorldPreviewDisableJump",
    "JumpPower = 0",
    "JumpHeight = 0",
):
    if forbidden in presentation:
        raise AssertionError(f"zone presentation must not own movement policy: {forbidden}")

print("Swimming traversal contract: PASS")
