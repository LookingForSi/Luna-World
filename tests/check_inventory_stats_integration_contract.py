#!/usr/bin/env python3
"""Static contract for authoritative inventory mutations and combat stat refresh."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


INVENTORY = read("src/server/services/InventoryService.luau")
STATS = read("src/server/services/StatsService.luau")
COMBAT = read("src/server/services/CombatService.luau")
PROFILE = read("src/shared/persistence/ProfileSchema.luau")

for token in (
    "PlayerDataService.getProfileCopy",
    "PlayerDataService.mutate",
    "InventoryRules.add",
    "EquipmentRules.equip",
    "EquipmentRules.unequip",
):
    if token not in INVENTORY:
        raise AssertionError(f"InventoryService boundary missing {token}")

for token in (
    "aggregateEquipmentModifiers",
    "ItemDefinitions",
    "StatRules.derive",
):
    if token not in STATS:
        raise AssertionError(f"StatsService equipment composition missing {token}")

for token in (
    "PlayerDataService.ProfileReady",
    "PlayerDataService.ProfileChanged",
    "CombatService.refreshPlayerStats",
    "CombatEffectService.recomputePlayerModifiers",
    "preserveRatio",
):
    if token not in COMBAT:
        raise AssertionError(f"Combat stat refresh contract missing {token}")

if "item record references an unknown definition" not in PROFILE:
    raise AssertionError("profile validation must reject unknown persistent item ids")
if "equipped item is incompatible with its slot" not in PROFILE:
    raise AssertionError("profile validation must enforce equipment referential integrity")

print("Inventory and equipment stat integration contract: PASS")
