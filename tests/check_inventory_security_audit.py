#!/usr/bin/env python3
"""Security audit contract for M2 inventory/profile requests."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


REQUESTS = read("src/shared/inventory/InventoryRequestRules.luau")
NETWORK = read("src/server/services/InventoryNetworkService.luau")
INVENTORY = read("src/server/services/InventoryService.luau")
DATA = read("src/server/services/PlayerDataService.luau")

for token in (
    "argumentCount ~= 2",
    "MAX_IDENTIFIER_LENGTH" if False else "MaxIdentifierLength",
    'Equip = true',
    'Unequip = true',
    'Consume = true',
    'Discard = true',
):
    if token not in REQUESTS:
        raise AssertionError(f"inventory request validation missing {token}")

if "ActionRequestMinIntervalSeconds" not in NETWORK:
    raise AssertionError("inventory actions must be per-player rate limited")
if "PlayerDataService.isReady(player)" not in NETWORK:
    raise AssertionError("inventory actions must require a ready canonical profile")

for token in (
    'return false, "NotOwned"',
    'return false, "Dead"',
    'return false, "Cooldown"',
    "EquipmentRules.equip",
    "EquipmentRules.unequip",
):
    if token not in INVENTORY:
        raise AssertionError(f"inventory service security boundary missing {token}")

for forbidden in (
    "SetXP",
    "SetLevel",
    "SetLuna",
    "SetQuantity",
    "SetInventory",
    "GrantItemRequest",
):
    if forbidden in NETWORK:
        raise AssertionError(f"forbidden client-authoritative mutation exposed: {forbidden}")

if "AccountSchema.validateCurrent(s.account)" not in DATA:
    raise AssertionError("every profile mutation must be validated before commit")

print("Inventory and profile malicious-request audit: PASS")
