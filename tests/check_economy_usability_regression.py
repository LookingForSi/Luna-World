#!/usr/bin/env python3
"""Focused regression contract for starter weapons, merchant sale UX, and real LV6 crafting."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")

starter = read("src/shared/economy/StarterGearRules.luau")
items = read("src/shared/definitions/ItemDefinitions.luau")
ui = read("src/client/ui/EconomyUi.luau")
rules = read("src/shared/economy/EconomyRules.luau")
balance = read("src/shared/economy/EconomyBalance.luau")
craft = read("src/shared/definitions/CraftingDefinitions.luau")
loot = read("src/shared/definitions/LootTableDefinitions.luau")

for token in (
    'knight = "weapon_training_sword"',
    'ranger = "weapon_ash_bow"',
    'mystic = "weapon_ash_staff"',
    "equippedWeaponMatchesArchetype",
    "forceStarterWeapon ~= true",
    "grantAndEquipForArchetype(staged, archetypeId, generateId, true)",
):
    if token not in starter:
        raise AssertionError(f"starter weapon regression contract missing: {token}")

for token in ('"Учебный меч"', '"Учебный лук"', '"Учебный посох"'):
    if token not in items:
        raise AssertionError(f"starter display name missing: {token}")

for token in (
    '"SellWorkspace"',
    '"ИНВЕНТАРЬ"',
    '"К ПРОДАЖЕ"',
    'quantity.Name = "Quantity"',
    "quantity.FocusLost",
    "enterPressed",
    '"Итого к получению: %d Luna"',
    "callbacks.sellBatch",
):
    if token not in ui:
        raise AssertionError(f"merchant sale UX contract missing: {token}")

if "function EconomyRules.sellBatch" not in rules:
    raise AssertionError("atomic sellBatch rule is missing")

# This must represent the actual quest path to LV6, not a late-game farming route.
for token in (
    "loot_young_wolf = 4",
    "loot_grey_wolf = 4",
    "loot_wolf_pack_leader = 1",
    "loot_goblin_scout = 4",
    "loot_goblin_warrior = 1",
    "loot_goblin_shaman = 1",
    "loot_spider = 4",
    "loot_brood_spider = 1",
):
    if token not in balance:
        raise AssertionError(f"LV6 route regression missing: {token}")

for token in (
    '"material_cured_leather", 3, 4',
    '"material_sturdy_thread", 3, 4',
    '"material_iron_billet", 2, 8',
    'i("material_iron_scrap", 2)',
    'i("material_magic_dust", 1)',
):
    if token not in craft:
        raise AssertionError(f"early crafting balance regression missing: {token}")

if 'signatureResourceEntry("material_magic_dust", 1.0)' not in loot:
    raise AssertionError("Goblin Shaman signature material must be reliable by LV6")

print("Economy usability + LV6 crafting regression contract: PASS")
