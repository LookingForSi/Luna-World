#!/usr/bin/env python3
"""Static contract for the v0.1 open-world mob content pass."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def text(path: str) -> str:
    candidate = ROOT / path
    if not candidate.exists():
        raise AssertionError(f"missing required mob-content file: {path}")
    return candidate.read_text(encoding="utf-8")


MOBS = text("src/shared/definitions/MobDefinitions.luau")
ABILITIES = text("src/shared/definitions/MobAbilityDefinitions.luau")
LAYOUT = text("src/shared/world/WorldLayout.luau")
MOB_SERVICE = text("src/server/services/MobService.luau")
MOB_AI = text("src/server/services/MobAIService.luau")
MOB_ABILITY_SERVICE = text("src/server/services/MobAbilityService.luau")
COMBAT = text("src/server/services/CombatService.luau")
MAIN = text("src/server/main.server.luau")

for mob_id in (
    "mob_young_wolf",
    "mob_grey_wolf",
    "mob_wolf_pack_leader",
    "mob_goblin_scout",
    "mob_goblin_warrior",
    "mob_goblin_shaman",
    "mob_goblin_chieftain",
    "mob_spider",
    "mob_brood_spider",
    "mob_dire_wolf",
    "mob_dire_wolf_alpha",
    "mob_forest_spider",
    "mob_skeleton",
    "mob_skeleton_archer",
    "mob_grave_guardian",
    "mob_fallen_acolyte",
    "mob_shrine_guardian",
    "mob_ancient_sentinel",
    "mob_ancient_watcher",
    "mob_moonbound_warden",
):
    if f'id = "{mob_id}"' not in MOBS:
        raise AssertionError(f"missing v0.1 mob definition {mob_id}")

for ability_id in (
    "goblin_sling_stone",
    "goblin_spirit_bolt",
    "goblin_war_chant",
	"goblin_cleave",
    "spider_venom_spit",
    "spider_crippling_venom",
    "dire_wolf_pounce",
    "skeleton_arrow",
    "acolyte_arcane_bolt",
    "ancient_sentinel_slam",
    "warden_enrage",
):
    if f'id = "{ability_id}"' not in ABILITIES:
        raise AssertionError(f"missing v0.1 mob ability {ability_id}")

for marker in (
    "spawn_young_wolf_farm",
    "spawn_wolf_pack_leader",
    "spawn_goblin_patrol_south",
    "spawn_goblin_patrol_east",
    "spawn_goblin_patrol_north",
    "spawn_goblin_patrol_west",
    "spawn_goblin_shaman_camp",
    "spawn_goblin_chieftain_camp",
    "spawn_spider_hollow_swarm",
    "spawn_spider_hollow_brood",
    "spawn_dire_wolf_alpha",
    "spawn_grave_guardian",
    "spawn_fallen_acolytes",
    "spawn_shrine_guardians",
    "spawn_moonbound_warden",
):
    if f'id = "{marker}"' not in LAYOUT:
        raise AssertionError(f"missing populated world marker {marker}")

if 'id = "spawn_spider_hollow_swarm"' not in LAYOUT or 'count = 8' not in LAYOUT:
    raise AssertionError("Spider Hollow must expose the eight-spider ordinary population")
if 'id = "spawn_spider_hollow_brood"' not in LAYOUT or 'count = 2' not in LAYOUT:
    raise AssertionError("Spider Hollow must expose two brood spiders")
for marker_id, count in (
    ("spawn_forest_spider_dark", 4),
    ("spawn_skeleton_cemetery_b", 3),
    ("spawn_fallen_acolytes", 5),
):
    marker_body = LAYOUT.split(f'id = "{marker_id}"', 1)[1].split("}", 1)[0]
    if f"count = {count}" not in marker_body:
        raise AssertionError(f"{marker_id} must use the approved population count {count}")
if 'socialGroupId = "goblin_patrol_' not in LAYOUT:
    raise AssertionError("Goblin patrols must use linked encounter groups")
if 'socialGroupId' in LAYOUT.split('id = "spawn_spider_hollow_swarm"', 1)[1].split("\n", 1)[0]:
    raise AssertionError("ordinary Spider Hollow spawn must remain non-social")

for token in (
    "marker.count or 1",
    "spawnOffset",
    'model:SetAttribute("SocialGroupId"',
    'model:SetAttribute("PhysicalDefense"',
    'model:SetAttribute("MagicDefense"',
    "removeMobPlaceholders",
):
    if token not in MOB_SERVICE:
        raise AssertionError(f"MobService population contract missing {token}")

for token in (
	'otherModel:GetAttribute("SocialGroupId") == typedSocialGroupId',
    "definition.socialAssistRadius",
	"MobAIRules.canRequestSocialAssist",
    "patrolDestination",
    "record.patrolRadius",
    "definition.basicAttackRange",
):
    if token not in MOB_AI:
        raise AssertionError(f"MobAI social/patrol contract missing {token}")

for token in (
    "DamageOverTime",
    "Crippling",
    "applyMobDebuff",
    "MobActionGenerationAttribute",
    "healthBelowFraction",
    "basicAttackRange",
):
    if token not in MOB_ABILITY_SERVICE:
        raise AssertionError(f"MobAbilityService authority contract missing {token}")

for token in (
    "HostileMovementMultiplierAttribute",
    "HostileAttackSpeedMultiplierAttribute",
    "getPlayerCombatStats",
    "applyMobDebuff",
):
    if token not in COMBAT:
        raise AssertionError(f"CombatService hostile-effect boundary missing {token}")

if "MobAbilityService.start()" not in MAIN or "MobAIService.start(MobAbilityService.requestAttack)" not in MAIN:
    raise AssertionError("server bootstrap must route mob attacks through MobAbilityService")

print("Mob Content Pass v0.1 contract: PASS")
