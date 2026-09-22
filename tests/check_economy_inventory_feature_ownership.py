#!/usr/bin/env python3
"""Gate F2 contract: Economy and Inventory have real feature ownership."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    candidate = ROOT / path
    assert candidate.exists(), f"missing F2 file: {path}"
    return candidate.read_text(encoding="utf-8")

adapter = read("src/client/bootstrap/adapters/ExistingClientComponents.luau")
economy_controller = read("src/client/features/economy/EconomyController.luau")
inventory_controller = read("src/client/features/inventory/InventoryController.luau")
economy_ui = read("src/client/features/economy/EconomyUi.luau")
inventory_ui = read("src/client/features/inventory/InventoryUi.luau")

legacy_economy_controller = read("src/client/controllers/EconomyController.luau")
legacy_inventory_controller = read("src/client/controllers/InventoryController.luau")
legacy_economy_ui = read("src/client/ui/EconomyUi.luau")
legacy_inventory_ui = read("src/client/ui/InventoryUi.luau")

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
    assert forbidden not in adapter, f"bootstrap still depends on legacy path {forbidden}"

assert "features.economy.EconomyController" in legacy_economy_controller
assert "features.inventory.InventoryController" in legacy_inventory_controller
assert "features.economy.EconomyUi" in legacy_economy_ui
assert "features.inventory.InventoryUi" in legacy_inventory_ui

for facade in (
    legacy_economy_controller,
    legacy_inventory_controller,
    legacy_economy_ui,
    legacy_inventory_ui,
):
    assert len(facade.splitlines()) <= 5, "legacy Economy/Inventory path must remain a thin compatibility facade"

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

print("Gate F2 Economy/Inventory feature ownership: PASS")
