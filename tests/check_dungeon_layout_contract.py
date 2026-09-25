#!/usr/bin/env python3
"""Static integration contract for traversable Selene geometry and one transform API."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


layout = read("src/shared/dungeon/DungeonLayout.luau")
world = read("src/server/features/dungeon/DungeonWorldService.luau")
encounter = read("src/server/features/dungeon/DungeonEncounterService.luau")
run = read("src/server/features/dungeon/DungeonRunService.luau")
dev = read("src/server/features/dungeon/DevCombinedDungeonAdapter.luau")
mob = read("src/server/services/MobService.luau")

for room_id in ("Entrance", "Pack1", "Miniboss", "Pack2", "Guardian", "Exit"):
    if f'id = "{room_id}"' not in layout:
        raise AssertionError(f"missing readable dungeon room: {room_id}")

for token in (
    "Layout.Rooms",
    "definition.endZ - definition.startZ",
    "origin * CFrame.new(localPosition)",
    "Layout.DevCombinedOffset",
    "function Service.toWorld",
    "function Service.isWithinBounds",
    "Layout.GateZ[index]",
):
    if token not in world:
        raise AssertionError(f"unified dungeon geometry contract missing: {token}")

for token in (
    "Layout.EncounterPositions[groupIndex]",
    "DungeonWorld.toWorld(localPosition)",
    "DungeonWorld.setGateClosed(group, false)",
    "spawnGroup(group + 1)",
    "telegraph.Parent = DungeonWorld.getRoot()",
):
    if token not in encounter:
        raise AssertionError(f"encounter transform/sequence contract missing: {token}")

if "Vector3.new(0,5,110)" in encounter or "index*120-60" in encounter:
    raise AssertionError("EncounterService must not carry an independent coordinate system")

for token in (
    "DungeonWorld.isWithinBounds(rootPart.Position)",
    'humanoid.Health=0',
    'log("PLAYER_OUT_OF_BOUNDS"',
    "DungeonWorld.getCheckpoint",
):
    if token not in run:
        raise AssertionError(f"OOB/checkpoint contract missing: {token}")

for token in (
    "DungeonWorld.start(true)",
    "DungeonWorld.getRoot() == nil",
    "rootConnection",
    "close()",
):
    if token not in dev:
        raise AssertionError(f"DevCombined cleanup/re-entry contract missing: {token}")

if "configuredMarkerActive[spawnMarkerId] = false" not in mob:
    raise AssertionError("retired dungeon encounter markers must not respawn stale mobs")

print("Dungeon layout, isolation, and OOB contract: PASS")
