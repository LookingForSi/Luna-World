#!/usr/bin/env python3
"""Static contract for process-lifetime service cleanup added at the M1 stabilization gate."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    candidate = ROOT / path
    if not candidate.exists():
        raise AssertionError(f"missing required file: {path}")
    return candidate.read_text(encoding="utf-8")


def require(path: str, token: str, message: str) -> None:
    if token not in read(path):
        raise AssertionError(message)


MAIN = "src/server/main.server.luau"
MOBS = "src/server/services/MobService.luau"
PROGRESSION = "src/server/services/ProgressionService.luau"
PLAYER_DATA = "src/server/services/PlayerDataService.luau"
LOOT = "src/server/services/LootService.luau"

require(MAIN, "game:BindToClose", "server bootstrap must own process-lifetime cleanup")
for token in (
    "StudioDebugService.stop()",
    "RespawnService.stop()",
    "LootService.stop()",
    "MobAIService.stop()",
    "MobService.stop()",
    "CombatService.stop()",
    "ProgressionService.stop()",
    "PlayerDataService.stop()",
):
    require(MAIN, token, f"server shutdown is missing {token}")

require(MOBS, "function MobService.stop()", "MobService must expose lifecycle cleanup")
require(MOBS, "serviceGeneration += 1", "MobService delayed respawns must be generation-guarded")
require(MOBS, "if not started or serviceGeneration ~= expectedGeneration then", "stale delayed mob respawns must be rejected")
require(MOBS, "table.clear(spawnedModels)", "MobService stop must forget spawned models")
require(MOBS, "table.clear(lastAttackerByEntityId)", "MobService stop must clear attribution state")

require(PROGRESSION, "profileReadyConnection", "ProgressionService must own its profile-ready connection")
require(PROGRESSION, "function ProgressionService.stop()", "ProgressionService must expose lifecycle cleanup")
require(PROGRESSION, "profileReadyConnection:Disconnect()", "ProgressionService stop must disconnect profile-ready events")
require(PLAYER_DATA, "function PlayerDataService.stop()", "PlayerDataService must expose lifecycle cleanup")
require(PLAYER_DATA, "playerRemovingConnection:Disconnect()", "PlayerDataService stop must disconnect player lifecycle events")
require(PLAYER_DATA, "releasePlayer(player)", "PlayerDataService shutdown must release active profile leases")
require(LOOT, "function LootService.stop()", "LootService must expose lifecycle cleanup")
require(LOOT, "mobDiedConnection:Disconnect()", "LootService stop must disconnect mob reward events")

print("Server service lifecycle contract: PASS")
