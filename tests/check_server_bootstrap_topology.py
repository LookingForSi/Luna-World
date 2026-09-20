#!/usr/bin/env python3

"""Verify that the server bootstrap follows the configured Rojo hierarchy."""

from pathlib import Path
import json
import re


ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILE = ROOT / "default.project.json"
BOOTSTRAP_FILE = ROOT / "src/server/main.server.luau"
EXPECTED_SERVICES = {
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
    "ProgressionService",
	"QuestService",
    "RespawnService",
    "StudioDebugService",
}


project = json.loads(PROJECT_FILE.read_text(encoding="utf-8"))
server_mapping = project["tree"]["ServerScriptService"]["Server"]["$path"]
assert server_mapping == "src/server", (
    "topology check expects src/server to map to ServerScriptService.Server"
)

source = BOOTSTRAP_FILE.read_text(encoding="utf-8")
resolved_services = set(
    re.findall(r"require\(script\.Parent\.services\.([A-Za-z0-9_]+)\)", source)
)
assert resolved_services == EXPECTED_SERVICES, (
    "Server/main and Server/services are siblings; service requires must resolve "
    f"through script.Parent.services (found {sorted(resolved_services)})"
)

print("Server bootstrap topology: PASS")
