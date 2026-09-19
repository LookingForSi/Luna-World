#!/usr/bin/env python3
"""Static contract for mob levels, target display and level-scaled XP."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


MOBS = text("src/shared/definitions/MobDefinitions.luau")
SERVICE = text("src/server/services/MobService.luau")
PROGRESSION = text("src/shared/progression/ProgressionRules.luau")
LOOT = text("src/server/services/LootService.luau")
HUD = text("src/client/ui/CombatHud.luau")

for token in (
    'id = "mob_young_wolf", displayName = "Молодой волк", level = 1',
    'id = "mob_grey_wolf", displayName = "Волк", level = 2',
    'id = "mob_wolf_pack_leader", displayName = "Вожак стаи", level = 3',
    'id = "mob_spider", displayName = "Ядовитый паук", level = 4',
    'id = "mob_moonbound_warden", displayName = "Лунный страж", level = 10',
):
    if token not in MOBS:
        raise AssertionError(f"v0.1 mob level tuning is missing {token}")

if 'model:SetAttribute("Level", definition.level)' not in SERVICE:
    raise AssertionError("mob level must replicate on the authoritative mob model")

for token in (
    "mobExperienceMultiplier",
    "difference == -4",
    "return 0",
    "calculateMobXP",
):
    if token not in PROGRESSION:
        raise AssertionError(f"level-scaled XP rule is missing {token}")

if "ProgressionService.awardMobXP(killer, definition.rewardXP, definition.level)" not in LOOT:
    raise AssertionError("mob death reward must use base XP and mob level")

if 'target:GetAttribute("Level")' not in HUD or '"LV %d · %s"' not in HUD:
    raise AssertionError("target HUD must display mob level")

print("Mob level and XP scaling contract: PASS")
