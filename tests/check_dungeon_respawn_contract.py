#!/usr/bin/env python3
"""Regression contract for single-owner dungeon respawn and OOB recovery."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str: return (ROOT / path).read_text(encoding="utf-8")

respawn = read("src/server/services/RespawnService.luau")
run = read("src/server/features/dungeon/DungeonRunService.luau")
world = read("src/server/features/dungeon/DungeonWorldService.luau")
dev = read("src/server/features/dungeon/DevCombinedDungeonAdapter.luau")

assert "player:LoadCharacter()" in respawn
assert "LoadCharacter" not in run, "DungeonRun must not own a second character reload lifecycle"
for token in ("function RespawnService.setContext", "function RespawnService.clearContext", "function RespawnService.placeAtContext", "context.resolveAnchor()"):
    assert token in respawn, f"generic respawn context contract missing: {token}"
for token in (
    "RespawnService.setContext", "RespawnService.clearContext", "RespawnService.placeAtContext",
    "Rules.checkpointForEncounter", "onParticipantDeath", "onParticipantPlaced",
    "wipeLatched", "characterProtected[player]", "unavailableParticipants[player.UserId]",
    'Diagnostics.reject("DUNGEON_WORLD_UNAVAILABLE"', 'Diagnostics.reject("RESPAWN_CONTEXT_UNAVAILABLE"',
    'log("DUNGEON_ADMISSION_PLACED"', 'log("DUNGEON_ADMISSION_REJECTED"', 'boundary = boundary', "DungeonWorld.inspectBounds",
):
    assert token in run, f"dungeon respawn/OOB contract missing: {token}"
assert "function Service.inspectBounds" in world
for boundary in ('"X"', '"Y"', '"minZ"', '"maxZ"'):
    assert boundary in world
assert run.count('log("PARTY_WIPE"') == 1, "wipe must have one centralized emission path"
assert "DungeonRun.stop()" in dev and dev.index("DungeonRun.stop()") < dev.index("DungeonWorld.stop()")
print("Dungeon single-owner respawn and OOB recovery contract: PASS")
