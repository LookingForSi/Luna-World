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

require(MAIN, "game:BindToClose", "server bootstrap must own process-lifetime cleanup")
for token in (
    "StudioDebugService.stop()",
    "RespawnService.stop()",
    "MobAIService.stop()",
    "MobService.stop()",
    "CombatService.stop()",
    "ProgressionService.stop()",
):
    require(MAIN, token, f"server shutdown is missing {token}")

require(MOBS, "function MobService.stop()", "MobService must expose lifecycle cleanup")
require(MOBS, "serviceGeneration += 1", "MobService delayed respawns must be generation-guarded")
require(MOBS, "if not started or serviceGeneration ~= expectedGeneration then", "stale delayed mob respawns must be rejected")
require(MOBS, "table.clear(spawnedModels)", "MobService stop must forget spawned models")
require(MOBS, "table.clear(lastAttackerByEntityId)", "MobService stop must clear attribution state")

require(PROGRESSION, "playerAddedConnection", "ProgressionService must own its PlayerAdded connection")
require(PROGRESSION, "function ProgressionService.stop()", "ProgressionService must expose lifecycle cleanup")
require(PROGRESSION, "playerAddedConnection:Disconnect()", "ProgressionService stop must disconnect PlayerAdded")

print("Server service lifecycle contract: PASS")
