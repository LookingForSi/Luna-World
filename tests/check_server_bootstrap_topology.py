#!/usr/bin/env python3

"""Verify that the role-aware server bootstrap preserves the DevCombined service topology."""

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILE = ROOT / "default.project.json"
MAIN = ROOT / "src/server/main.server.luau"
ADAPTERS = ROOT / "src/server/bootstrap/adapters/ExistingServerComponents.luau"
DEV_MANIFEST = ROOT / "src/server/bootstrap/manifests/DevCombinedServerManifest.luau"

EXPECTED_SERVICES = {
    "CharacterService",
    "EconomyNetworkService",
    "EconomyService",
    "EconomyWorldService",
    "InventoryNetworkService",
    "WorldDropService",
    "LootService",
    "MobAIService",
    "MobAbilityService",
    "MobService",
    "NpcWorldService",
    "PlayerDataService",
    "PlayerRegenerationService",
    "ProgressionService",
    "QuestService",
    "TravelService",
    "RespawnService",
    "StudioDebugService",
}

EXPECTED_DEV_ORDER = [
    "worldBootstrap",
    "worldSpawnAnchor",
    "devCombinedGameplay",
]

LEGACY_START_ORDER = [
    "EconomyService.start()",
    "PlayerDataService.start()",
    "CharacterService.start()",
    "ProgressionService.start()",
    "CombatService.start()",
    "PlayerRegenerationService.start()",
    "RespawnService.start()",
    "StudioDebugService.start()",
    "MobAbilityService.start()",
    "MobAIService.start(MobAbilityService.requestAttack)",
    "MobService.start()",
    "LootService.start()",
    "WorldDropService.start()",
    "InventoryNetworkService.start()",
    "EconomyNetworkService.start()",
    "EconomyWorldService.start()",
    "QuestService.start()",
    "TravelService.start()",
    "NpcWorldService.start()",
]

LEGACY_STOP_ORDER = [
    "StudioDebugService.stop()",
    "RespawnService.stop()",
    "PlayerRegenerationService.stop()",
    "InventoryNetworkService.stop()",
    "WorldDropService.stop()",
    "NpcWorldService.stop()",
    "EconomyWorldService.stop()",
    "TravelService.stop()",
    "QuestService.stop()",
    "EconomyNetworkService.stop()",
    "EconomyService.stop()",
    "LootService.stop()",
    "MobAIService.stop()",
    "MobAbilityService.stop()",
    "MobService.stop()",
    "CombatService.stop()",
    "ProgressionService.stop()",
    "CharacterService.stop()",
    "PlayerDataService.stop()",
]
project = json.loads(PROJECT_FILE.read_text(encoding="utf-8"))
server_mapping = project["tree"]["ServerScriptService"]["Server"]["$path"]
assert server_mapping == "src/server"

main = MAIN.read_text(encoding="utf-8")
assert "ServerBootstrap.start(manifest)" in main
assert "PlaceRuntime.resolve(game.PlaceId, game.GameId" in main
assert ".services." not in main, "thin server entrypoint must not require gameplay services directly"

adapters = ADAPTERS.read_text(encoding="utf-8")
resolved_services = set(
    re.findall(r"require\(serverRoot\.services\.([A-Za-z0-9_]+)\)", adapters)
)
assert "require(serverRoot.features.combat.CombatCoordinator)" in adapters
assert resolved_services == EXPECTED_SERVICES, (
    f"server adapter service set changed: {sorted(resolved_services)}"
)
assert "MobAIService.start(MobAbilityService.requestAttack)" in adapters
assert "workspace:WaitForChild(MoonfallAuthoringContract.RootName, 15)" in adapters

start_positions = [adapters.index(token) for token in LEGACY_START_ORDER]
assert start_positions == sorted(start_positions), "DevCombined legacy startup order changed"
stop_positions = [adapters.index(token) for token in LEGACY_STOP_ORDER]
assert stop_positions == sorted(stop_positions), "DevCombined legacy shutdown order changed"

dev = DEV_MANIFEST.read_text(encoding="utf-8")
actual_order = re.findall(r"Components\.([A-Za-z0-9_]+)\(\)", dev)
assert actual_order == EXPECTED_DEV_ORDER, (
    f"DevCombined startup order changed: {actual_order}"
)

print("Server bootstrap topology: PASS")
