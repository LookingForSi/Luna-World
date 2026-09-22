#!/usr/bin/env python3
"""Static contract for integrating the accepted world blockout with manifest-owned gameplay."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def text(path: str) -> str:
    candidate = ROOT / path
    if not candidate.exists():
        raise AssertionError(f"missing required integration file: {path}")
    return candidate.read_text(encoding="utf-8")

MAIN = text("src/server/main.server.luau")
ADAPTERS = text("src/server/bootstrap/adapters/ExistingServerComponents.luau")
MOBS = text("src/server/services/MobService.luau")
LAYOUT = text("src/shared/world/WorldLayout.luau")
WORLD_BOOTSTRAP = text("tools/worldgen/WorldBootstrap.luau")
PROJECT = text("default.project.json")

if "ServerBootstrap.start(manifest)" not in MAIN:
    raise AssertionError("server entrypoint must delegate runtime startup to ServerBootstrap")
if "MoonfallAuthoringContract.RootName" not in ADAPTERS:
    raise AssertionError("world spawn integration must use the shared authored-root contract")
for token in (
    'CollectionService:AddTag(worldSpawn, RespawnConfig.AnchorTag)',
    'RespawnConfig.LunaVillageSettlementId',
    '"luna_village_spawn"',
):
    if token not in ADAPTERS:
        raise AssertionError(f"world respawn integration missing {token}")

for token in (
    "Shared.world.WorldLayout",
    "script.Parent.Parent.world.TerrainGrounding",
    "configuredWorldSpawns",
    "marker.spawnEnabled == false",
    "definitionKeyForId",
    'descendant:GetAttribute("Purpose") == "MobPlaceholder"',
):
    if token not in MOBS:
        raise AssertionError(f"world-aware MobService contract missing {token}")

if "local SPAWNS =" in MOBS:
    raise AssertionError("legacy hard-coded playground spawn coordinates must not remain")

if '"mob_meadow_spider"' in LAYOUT:
    raise AssertionError("Spider Hollow markers must use the gameplay-stable mob_spider id")
if '"mob_spider"' not in LAYOUT:
    raise AssertionError("Spider Hollow gameplay marker is missing")

for token in (
    "PlayableWorldBlockout",
    "TraversalRecovery",
    "function WorldBootstrap.start()",
    "function WorldBootstrap.stop()",
):
    if token not in WORLD_BOOTSTRAP:
        raise AssertionError(f"world bootstrap missing {token}")

if '"$path": "src/server"' not in PROJECT or '"$path": "src/client"' not in PROJECT:
    raise AssertionError("default gameplay project must map integrated world source transitively")

print("World + gameplay integration contract: PASS")
