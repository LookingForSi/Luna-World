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

# Lake terrain is intentionally rolled back to the last accepted pre-experiment
# geometry. Stock Swimming remains enabled globally by MovementController.
for token in (
    'Purpose", "TraversalBarrier"',
    "LAKE_SURFACE_DROP = 8",
    "LAKE_WATER_DEPTH = 12",
    "LAKE_AIR_CLEARANCE_HEIGHT = 28",
    "shapeGoblinCemeteryLakeHillCliff",
    '"WaterRecovery%02d"',
    'HazardKind = "Lake"',
    'HillBankCliff", true',
):
    if token not in north:
        raise AssertionError(f"pre-experiment lake rollback contract missing: {token}")

for lake_forbidden in (
    "prepareGoblinCampBoundaryShelf",
    "fillFlatLakeSlab",
    "fillContinuousLakePath",
    "carveLakeDisc",
    "LakeBedFilled",
    "ContainedWithinWorldBounds",
):
    if lake_forbidden in north:
        raise AssertionError(f"experimental lake terrain still present after rollback: {lake_forbidden}")

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
