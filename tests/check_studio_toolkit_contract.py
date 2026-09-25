#!/usr/bin/env python3
"""Static contract for the expanded Studio traversal/progression/loadout toolkit."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


server = read("src/server/services/StudioDebugService.luau")
client = read("src/client/ui/StudioTestPanel.luau")
default_project = read("default.project.json")

for remote in (
    "StudioUnlockAllMissions",
    "StudioGrantTopGear",
    "StudioTeleport",
):
    if remote in default_project:
        raise AssertionError(f"{remote} must remain Studio-runtime-only")
    if f'createRemote("{remote}")' not in server:
        raise AssertionError(f"server Studio remote missing: {remote}")
    if f'WaitForChild("{remote}", 5)' not in client:
        raise AssertionError(f"client Studio remote missing: {remote}")

for token in (
    "completeAllMissionsForStudio",
    'State = "Completed"',
    "progress[objective.id] = objective.required",
    "TOP_GEAR_BY_ARCHETYPE",
    "weapon_moonsteel_sword",
    "weapon_moonstring_bow",
    "weapon_moonveil_staff",
    "accessory_lunar_sigil",
    "ProgressionConfig.LevelCap",
    "WorldLayout.RuinsOfSeleneEntranceQuery",
    "groundTeleportTarget",
    "character:PivotTo",
):
    if token not in server:
        raise AssertionError(f"Studio server toolkit contract missing: {token}")

for token in (
    '"ALL MISSIONS"',
    '"TOP GEAR"',
    '"ТЕЛЕПОРТ"',
    'button.Name = "Teleport_" .. destination.id',
    '{ id = "village"',
    '{ id = "ancient"',
    '{ id = "ruins"',
):
    if token not in client:
        raise AssertionError(f"Studio client toolkit contract missing: {token}")

print("Studio traversal/progression/loadout toolkit contract: PASS")
