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
    'id = "mob_spider", displayName = "Ядовитый паук", level = 6',
    'id = "mob_brood_spider", displayName = "Паук-матка", level = 8',
    'id = "mob_dire_wolf", displayName = "Лютый волк", level = 9',
    'id = "mob_dire_wolf_alpha", displayName = "Альфа лютых волков", level = 11',
    'id = "mob_skeleton_archer", displayName = "Скелет-лучник", level = 12',
    'id = "mob_grave_guardian", displayName = "Могильный страж", level = 13',
    'id = "mob_ancient_sentinel", displayName = "Древний страж", level = 13',
    'id = "mob_ancient_watcher", displayName = "Древний наблюдатель", level = 14',
    'id = "mob_moonbound_warden", displayName = "Лунный страж", level = 14',
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

if "ProgressionService.awardMobXP(player, xpShares[player.UserId], definition.level)" not in LOOT:
    raise AssertionError("party mob rewards must use budget-preserving XP shares and mob level")

if 'target:GetAttribute("Level")' not in HUD or '"LV %d · %s"' not in HUD:
    raise AssertionError("target HUD must display mob level")

print("Mob level and XP scaling contract: PASS")
