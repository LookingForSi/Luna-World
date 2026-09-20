#!/usr/bin/env python3
"""Focused regression contract for starter weapons and merchant batch-sale UX."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

starter = (ROOT / "src/shared/economy/StarterGearRules.luau").read_text(encoding="utf-8")
service = (ROOT / "src/server/services/EconomyService.luau").read_text(encoding="utf-8")
studio = (ROOT / "src/server/services/StudioDebugService.luau").read_text(encoding="utf-8")
items = (ROOT / "src/shared/definitions/ItemDefinitions.luau").read_text(encoding="utf-8")
ui = (ROOT / "src/client/ui/EconomyUi.luau").read_text(encoding="utf-8")
network = (ROOT / "src/server/services/EconomyNetworkService.luau").read_text(encoding="utf-8")
rules = (ROOT / "src/shared/economy/EconomyRules.luau").read_text(encoding="utf-8")

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

for token in (
    '"Учебный меч"',
    '"Учебный лук"',
    '"Учебный посох"',
):
    if token not in items:
        raise AssertionError(f"starter display name missing: {token}")

if "PlayerDataService.ProfileReady:Connect(grantStarter)" not in service:
    raise AssertionError("profile-ready starter repair is not wired")
if "EconomyService._switchArchetypeForStudio" not in studio:
    raise AssertionError("Studio archetype switch must use the persistent starter transition")

for token in (
    '"SellWorkspace"',
    '"ИНВЕНТАРЬ"',
    '"К ПРОДАЖЕ"',
    '"SellInventory"',
    '"SellCart"',
    'quantity.Name = "Quantity"',
    "quantity.FocusLost",
    "enterPressed",
    '"Итого к получению: %d Luna"',
    '"ПРОДАТЬ ВЫБРАННОЕ · +%d Luna"',
    "callbacks.sellBatch",
):
    if token not in ui:
        raise AssertionError(f"merchant sale UX contract missing: {token}")

for token in (
    "EconomyRequestRules.validateSellBatch",
    "EconomyService.sellBatch",
    "if ok then push(player) end",
):
    if token not in network:
        raise AssertionError(f"merchant batch network contract missing: {token}")

if "function EconomyRules.sellBatch" not in rules:
    raise AssertionError("atomic sellBatch rule is missing")

print("Economy usability regression contract: PASS")
