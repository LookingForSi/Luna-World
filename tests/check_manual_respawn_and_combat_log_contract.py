#!/usr/bin/env python3
"""Static contract for manual respawn and the toggleable combat log."""

from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    candidate = ROOT / path
    if not candidate.exists():
        raise AssertionError(f"missing required file: {path}")
    return candidate.read_text(encoding="utf-8")


def require(path: str, token: str, message: str) -> None:
    if token not in read(path):
        raise AssertionError(message)


for project in ("default.project.json", "test.project.json"):
    data = json.loads(read(project))
    remotes = data["tree"]["ReplicatedStorage"]["Remotes"]
    assert remotes["RespawnRequest"]["$className"] == "RemoteEvent", f"{project} must expose RespawnRequest"

require("src/shared/config/RespawnConfig.luau", 'RespawnPendingAttribute = "RespawnPending"', "respawn pending state must have one stable replicated name")
require("src/server/services/RespawnService.luau", "RespawnRules.canRequestRespawn", "server must gate explicit respawn requests")
require("src/server/services/RespawnService.luau", "respawnRequest.OnServerEvent", "server must own the respawn remote")
require("src/server/services/RespawnService.luau", "nearestRegisteredAnchor(origin) or nearestSpawnLocation(origin)", "playground must have a SpawnLocation compatibility fallback")
require("src/server/services/RespawnService.luau", "player:LoadCharacter()", "accepted respawn request must recreate the character")
if "task.delay(RespawnConfig.RespawnDelaySeconds" in read("src/server/services/RespawnService.luau"):
    raise AssertionError("player death must not auto-respawn on a timer")

require("src/client/ui/RespawnPrompt.luau", "Вы были убиты", "death prompt must explain the state")
require("src/client/ui/RespawnPrompt.luau", "Вернуться в ближайший город?", "death prompt must ask for manual return")
require("src/client/ui/RespawnPrompt.luau", "respawnRequest:FireServer()", "death prompt must request respawn without client-owned destination")
require("src/client/ui/RespawnPrompt.luau", "Вернуться в город", "declining respawn must leave a later return affordance")

require("src/server/features/combat/CombatCoordinator.luau", 'presentationKey = "mob_basic_attack"', "incoming mob damage must be published as confirmed presentation data")
require("src/server/features/combat/CombatCoordinator.luau", "definitionId = definition.id", "incoming damage presentation needs the mob definition id")
require("src/client/ui/CombatLog.luau", "ClientCombatLogRules.isRelevant", "combat log must filter to local incoming/outgoing events")
require("src/client/ui/CombatLog.luau", "Лог  ▲", "combat log must be user-toggleable")
require("src/client/ui/CombatLog.luau", "цель замедлена", "combat log must make Snare confirmation visible")
require("src/client/ui/CombatLog.luau", "защита +%d%%", "combat log must expose Defensive Stance magnitude")
require("src/client/bootstrap/adapters/ExistingClientComponents.luau", "CombatLog.start()", "client bootstrap must start combat log")
require("src/client/bootstrap/adapters/ExistingClientComponents.luau", "RespawnPrompt.start()", "client bootstrap must start respawn prompt")

print("Manual respawn and combat log contract: PASS")
