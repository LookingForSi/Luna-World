#!/usr/bin/env python3
"""Static contract for manifest-owned process lifetime and service cleanup."""

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

BOOTSTRAP = "src/server/bootstrap/ServerBootstrap.luau"
RUNTIME = "src/shared/core/runtime/RuntimeManifest.luau"
ADAPTERS = "src/server/bootstrap/adapters/ExistingServerComponents.luau"
WORLD_BOOTSTRAP = "tools/worldgen/WorldBootstrap.luau"
TRAVERSAL = "src/server/world/TraversalRecovery.luau"
MOBS = "src/server/services/MobService.luau"
PROGRESSION = "src/server/services/ProgressionService.luau"
PLAYER_DATA = "src/server/services/PlayerDataService.luau"
LOOT = "src/server/services/LootService.luau"
WORLD_DROP = "src/server/services/WorldDropService.luau"

require(BOOTSTRAP, "game:BindToClose(stop)", "ServerBootstrap must own process-lifetime cleanup")
require(BOOTSTRAP, "RuntimeManifest.start(manifest)", "ServerBootstrap must delegate ordered lifecycle")
require(RUNTIME, "for index = #started, 1, -1 do", "runtime cleanup must be reverse-order")
require(RUNTIME, "pcall(component.stop)", "one component stop failure must not block later cleanup")
require(RUNTIME, "if stopped then", "runtime shutdown must be idempotent")

for token in (
    "StudioDebugService.stop",
    "RespawnService.stop",
    "LootService.stop",
    "WorldDropService.stop",
    "MobAIService.stop",
    "MobAbilityService.stop",
    "MobService.stop",
    "CombatService.stop",
    "ProgressionService.stop",
    "CharacterService.stop",
    "PlayerDataService.stop",
    "EconomyService.stop",
):
    require(ADAPTERS, token, f"server lifecycle adapter is missing {token}")

require(WORLD_BOOTSTRAP, "function WorldBootstrap.stop()", "world bootstrap must be lifecycle-managed")
require(WORLD_BOOTSTRAP, "traversalRecovery().stop()", "dev world bootstrap stop must stop traversal recovery")
require(TRAVERSAL, "function TraversalRecovery.stop()", "TraversalRecovery must expose cleanup")
require(TRAVERSAL, "serviceGeneration += 1", "TraversalRecovery async loop must be generation-guarded")
require(TRAVERSAL, "connection:Disconnect()", "TraversalRecovery must disconnect player lifecycle events")

require(MOBS, "function MobService.stop()", "MobService must expose lifecycle cleanup")
require(MOBS, "serviceGeneration += 1", "MobService delayed respawns must be generation-guarded")
require(MOBS, "if not started or serviceGeneration ~= expectedGeneration then", "stale delayed mob respawns must be rejected")
require(MOBS, "table.clear(spawnedModels)", "MobService stop must forget spawned models")
require(MOBS, "table.clear(lastAttackerByEntityId)", "MobService stop must clear attribution state")

require(PROGRESSION, "profileReadyConnection", "ProgressionService must own its profile-ready connection")
require(PROGRESSION, "function ProgressionService.stop()", "ProgressionService must expose lifecycle cleanup")
require(PROGRESSION, "profileReadyConnection:Disconnect()", "ProgressionService stop must disconnect profile-ready events")
require(PLAYER_DATA, "function PlayerDataService.stop()", "PlayerDataService must expose lifecycle cleanup")
require(PLAYER_DATA, "connection:Disconnect()", "PlayerDataService stop must disconnect player lifecycle events")
require(PLAYER_DATA, "releasePlayer(player)", "PlayerDataService shutdown must release active profile leases")
require(LOOT, "function LootService.stop()", "LootService must expose lifecycle cleanup")
require(LOOT, "killResolvedConnection:Disconnect()", "LootService stop must disconnect resolved reward events")
require(WORLD_DROP, "function WorldDropService.stop()", "WorldDropService must expose lifecycle cleanup")
require(WORLD_DROP, "connection:Disconnect()", "WorldDropService stop must disconnect pickup prompts")

print("Server service lifecycle contract: PASS")
