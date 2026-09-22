#!/usr/bin/env python3
"""Static characterization for the Gate A client bootstrap migration."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

main = read("src/client/main.client.luau")
adapter = read("src/client/bootstrap/adapters/ExistingClientComponents.luau")
application = read("src/client/bootstrap/ClientApplication.luau")

assert "ClientApplication.new" in main
assert ".controllers." not in main and ".ui." not in main, "thin client entrypoint must not require feature controllers/UI"
assert "script.Destroying:Connect" in main

assert 'GetAttribute("CharacterReady")' in application
assert "CharacterLobbyController.stop()" in adapter
assert adapter.index("MovementController.start()") < adapter.index("TargetController.start")
assert adapter.index("TargetController.start") < adapter.index("EconomyUi.start")
assert adapter.index("TargetController.start") < adapter.index("QuestController.start")
assert adapter.index("syncActionBar()") < adapter.index("EconomyUi.start")
assert "characterReadyConnection:Disconnect()" in application
assert "arrivalReadyConnection:Disconnect()" in application
assert "archetypeConnection:Disconnect()" in adapter

for token in (
    "InventoryController.stop()",
    "EconomyController.stop()",
    "QuestController.stop()",
    "ResponsiveUiController.stop()",
    "EconomyUi.stop()",
    "InventoryUi.stop()",
    "StudioTestPanel.stop()",
    "MovementController.stop()",
    "CombatPresentationController.stop()",
    "CombatInputController.stop()",
    "ActionBar.stop()",
    "TargetController.stop()",
    "RespawnPrompt.stop()",
    "CombatLog.stop()",
    "CombatHud.stop()",
):
    assert token in adapter, f"client gameplay cleanup missing {token}"

print("Client bootstrap topology: PASS")
