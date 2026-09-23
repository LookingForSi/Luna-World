#!/usr/bin/env python3
"""Client feature ownership contract for Economy and Inventory."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    candidate = ROOT / path
    assert candidate.exists(), f"missing Economy/Inventory feature file: {path}"
    return candidate.read_text(encoding="utf-8")


adapter = read("src/client/bootstrap/adapters/ExistingClientComponents.luau")
economy_controller = read("src/client/features/economy/EconomyController.luau")
inventory_controller = read("src/client/features/inventory/InventoryController.luau")
economy_ui = read("src/client/features/economy/EconomyUi.luau")
inventory_ui = read("src/client/features/inventory/InventoryUi.luau")

for token in (
    "clientRoot.features.economy.EconomyController",
    "clientRoot.features.inventory.InventoryController",
    "clientRoot.features.economy.EconomyUi",
    "clientRoot.features.inventory.InventoryUi",
):
    assert token in adapter, f"bootstrap does not use feature-owned module {token}"

for forbidden in (
    "clientRoot.controllers.EconomyController",
    "clientRoot.controllers.InventoryController",
    "clientRoot.ui.EconomyUi",
    "clientRoot.ui.InventoryUi",
):
    assert forbidden not in adapter, f"bootstrap regressed to legacy path {forbidden}"

for legacy_path in (
    "src/client/controllers/EconomyController.luau",
    "src/client/controllers/InventoryController.luau",
    "src/client/ui/EconomyUi.luau",
    "src/client/ui/InventoryUi.luau",
):
    assert not (ROOT / legacy_path).exists(), f"obsolete compatibility facade returned: {legacy_path}"

for token in ("EconomyRequest", "EconomySnapshot", "function EconomyController.start", "function EconomyController.stop"):
    assert token in economy_controller, f"Economy controller lost {token}"

for token in (
    "InventoryActionRequest",
    "InventorySnapshotRequest",
    "function InventoryController.start",
    "function InventoryController.stop",
    "requestQuickUse",
):
    assert token in inventory_controller, f"Inventory controller lost {token}"

for token in ("SellConfirm", "sellBatch", "craft", "HudLayout.makeCloseButton", "function EconomyUi.start", "function EconomyUi.stop"):
    assert token in economy_ui, f"Economy UI lost {token}"

for token in ("assignQuickSlot", "HudLayout.makeCloseButton", "function InventoryUi.start", "function InventoryUi.stop"):
    assert token in inventory_ui, f"Inventory UI lost {token}"

assert "script.Parent.Parent.Parent.ui.HudLayout" in economy_ui
assert "script.Parent.Parent.Parent.ui.HudLayout" in inventory_ui

print("Economy/Inventory feature ownership: PASS")
