#!/usr/bin/env python3
"""Static contract for one-death/one-reward loot and consumable boundaries."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


LOOT = read("src/server/services/LootService.luau")
INVENTORY = read("src/server/services/InventoryService.luau")
MAIN = read("src/server/bootstrap/adapters/ExistingServerComponents.luau")
LOG = read("src/client/ui/CombatLog.luau")
CONFIG = read("src/shared/config/InventoryConfig.luau")

for token in (
    "RewardLedger.new",
    "rewardLedger:mark(entityId)",
    "ProgressionService.awardMobXP",
    "PlayerDataService.mutate",
    "InventoryService.grantItem",
    '"loot_item_full"',
):
    if token not in LOOT:
        raise AssertionError(f"LootService contract missing {token}")

if "KillCreditService.KillResolved:Connect" not in LOOT:
    raise AssertionError("loot must consume the canonical resolved kill context")

if "LootService.start" not in MAIN or "LootService.stop" not in MAIN:
    raise AssertionError("server bootstrap must own LootService lifecycle")

for token in ('"xp"', '"luna"', '"loot_item"', '"loot_item_full"'):
    if token not in LOG:
        raise AssertionError(f"player log must render reward type {token}")

for token in (
    "function InventoryService.consume",
    "InventoryRules.discard",
    "CombatCoordinator.restorePlayerResource",
    "humanoid.Health",
):
    if token not in INVENTORY:
        raise AssertionError(f"consumable path missing {token}")

if "ConsumableCooldownSeconds = 5" not in CONFIG:
    raise AssertionError("consumables must use the approved five second cooldown")

print("Loot and consumable integration contract: PASS")
