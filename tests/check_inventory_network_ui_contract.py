#!/usr/bin/env python3
"""Static contract for inventory remotes, UI and client-authoritative rejection boundaries."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


DEFAULT = read("default.project.json")
TEST = read("test.project.json")
NETWORK = read("src/server/services/InventoryNetworkService.luau")
SERVICE = read("src/server/services/InventoryService.luau")
CONTROLLER = read("src/client/controllers/InventoryController.luau")
UI = read("src/client/ui/InventoryUi.luau")
BAR = read("src/client/ui/ActionBar.luau")
WORLD_DROP = read("src/server/services/WorldDropService.luau")
MAIN = read("src/server/main.server.luau")
CLIENT = read("src/client/main.client.luau")

for remote in (
    "InventoryActionRequest",
    "InventorySnapshotRequest",
    "InventorySnapshot",
    "InventoryActionResult",
):
    if remote not in DEFAULT or remote not in TEST:
        raise AssertionError(f"inventory remote {remote} must exist in both Rojo trees")

for token in (
    "InventoryRequestRules.validateAction",
    "ActionRequestMinIntervalSeconds",
    "PlayerDataService.isReady",
    "InventoryService.equip",
    "InventoryService.unequip",
    "InventoryService.consume",
    "InventoryService.discard",
    "WorldDropService.spawnForPlayer",
):
    if token not in NETWORK:
        raise AssertionError(f"inventory network boundary missing {token}")

for forbidden in ("SetInventory", "SetXP", "SetEquipment", "GrantItemRequest"):
    if forbidden in NETWORK:
        raise AssertionError(f"client must not get a generic authoritative setter: {forbidden}")

if "createClientSnapshot" not in SERVICE:
    raise AssertionError("InventoryService must produce a sanitized client snapshot")
if "InventoryNetworkService.start()" not in MAIN or "InventoryNetworkService.stop()" not in MAIN:
    raise AssertionError("server bootstrap must own inventory network lifecycle")

for token in ("Enum.KeyCode.T", "Enum.KeyCode.Zero", "Enum.KeyCode.ButtonSelect", "BindActionAtPriority", "ContextActionPriority.High", "UserInputService.InputBegan", "GetFocusedTextBox", "requestSnapshot", "assignQuickSlot", "requestQuickUse", "getQuickSlotState"):
    if token not in CONTROLLER:
        raise AssertionError(f"inventory controller missing {token}")

for token in ('"InventoryPanel"', '"InventoryList"', '"EquipmentList"', '"Equip"', '"Unequip"', '"Use"', '"Discard"', '"QuickSlot"', '"Filter" .. selectedFilter', '"ЗЕЛЬЯ"', '"ВЕЩИ"', '"РЕСУРСЫ"', "matchesFilter", "UIGridLayout", "AutomaticCanvasSize", "assignQuickSlot"):
    if token not in UI:
        raise AssertionError(f"inventory UI missing {token}")

for token in ('"Inventory"', '"ИНВЕНТАРЬ [T]"', '"ИНВЕНТАРЬ [SELECT]"', '"[0]"', "quickSlotButton", "GetLastInputType", "LastInputTypeChanged"):
    if token not in BAR:
        raise AssertionError(f"primary action block missing inventory access: {token}")

for token in ("PickupPrompt", '"Подобрать"', "InventoryService.grantItem", "DropNameplate", "DropHighlight", "DROP_LIFETIME_SECONDS = 600"):
    if token not in WORLD_DROP:
        raise AssertionError(f"world drop presentation/pickup missing {token}")

if "blocker.BackgroundTransparency = 1" not in UI:
    raise AssertionError("inventory modal blocker must capture input without blacking out the screen")
if "panel.BackgroundTransparency = 0.03" not in UI:
    raise AssertionError("inventory panel must remain readable over the world")

if "InventoryUi.start" not in CLIENT or "InventoryController.start" not in CLIENT:
    raise AssertionError("client bootstrap must start inventory UI/controller")

print("Inventory network and UI contract: PASS")
