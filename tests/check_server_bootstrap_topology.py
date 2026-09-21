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
    "CombatService",
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
    "economy",
    "playerData",
    "character",
    "progression",
    "combat",
    "regeneration",
    "respawn",
    "studioDebug",
    "mobAbilities",
    "mobAI",
    "mobs",
    "loot",
    "worldDrops",
    "inventoryNetwork",
    "economyNetwork",
    "economyWorld",
    "quests",
    "travel",
    "npcWorld",
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
assert resolved_services == EXPECTED_SERVICES, (
    f"server adapter service set changed: {sorted(resolved_services)}"
)
assert "MobAIService.start(MobAbilityService.requestAttack)" in adapters
assert 'workspace:WaitForChild("LunaWorldPlayableBlockout", 15)' in adapters

dev = DEV_MANIFEST.read_text(encoding="utf-8")
actual_order = re.findall(r"Components\.([A-Za-z0-9_]+)\(\)", dev)
assert actual_order == EXPECTED_DEV_ORDER, (
    f"DevCombined startup order changed: {actual_order}"
)

print("Server bootstrap topology: PASS")
