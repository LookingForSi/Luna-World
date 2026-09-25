#!/usr/bin/env python3
"""Regression contract for authored/generated Moonfall ownership in DevCombined."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
wrapper = (ROOT / "tools/worldgen/DevCombinedWorldBootstrap.luau").read_text()
adapters = (ROOT / "src/server/bootstrap/adapters/ExistingServerComponents.luau").read_text()
server_bootstrap = (ROOT / "src/server/bootstrap/ServerBootstrap.luau").read_text()
lobby = (ROOT / "src/client/features/lobby/CharacterLobbyController.luau").read_text()
rules = (ROOT / "src/shared/world/DevCombinedWorldRules.luau").read_text()

for project in ("default.project.json", "projects/dev-combined.project.json"):
    data = json.loads((ROOT / project).read_text())
    worldgen = data["tree"]["ServerScriptService"]["Worldgen"]
    assert "DevCombinedWorldBootstrap" in worldgen

assert 'Contract.AuthoredManagedBy' in rules
assert 'Contract.GeneratorManagedBy' in rules
assert 'OwnershipRules.resolve(#found, managedBy)' in wrapper
assert 'DevCombined refuses Workspace.%s state' in wrapper
assert 'GeneratedBootstrap.start()' in wrapper
assert 'GeneratedBootstrap.stop()' in wrapper
assert 'traversalRecovery().start(root, spawn)' in wrapper
assert 'traversalRecovery().stop()' in wrapper
assert 'FindFirstChild("DevCombinedWorldBootstrap")' in adapters
assert 'publishState("Failed: "' in server_bootstrap
assert 'Сервер не запустился. Проверьте Studio Output.' in lobby
print("DevCombined world ownership/startup regression contract: PASS")
