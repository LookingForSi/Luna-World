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
    "wolf_pack_howl",
    "goblin_sling_stone",
    "goblin_spirit_bolt",
    "goblin_war_chant",
    "goblin_shaman_hex",
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
    "spawn_young_wolf_farm_forward",
    "spawn_wolf_pack_leader",
    "spawn_wolf_pack_moonfall",
    "spawn_wolf_pack_moonfall_leader",
    "spawn_goblin_patrol_south",
    "spawn_goblin_patrol_east",
    "spawn_goblin_patrol_north",
    "spawn_goblin_patrol_west",
    "spawn_goblin_gate_pair_south",
    "spawn_goblin_gate_pair_north",
    "spawn_goblin_shaman_camp",
    "spawn_goblin_inner_pair_a_scout",
    "spawn_goblin_inner_pair_a_warrior",
    "spawn_goblin_inner_pair_b_scout",
    "spawn_goblin_inner_pair_b_warrior",
    "spawn_goblin_chieftain_camp",
    "spawn_goblin_chieftain_guard",
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

young_wolf_farm_body = LAYOUT.split('id = "spawn_young_wolf_farm"', 1)[1].split("}", 1)[0]
for token in ("scaleXZ(-280, 8, 430)", "count = 4", "patrolRadius = scaleDistance(70)", "patrolCycleSeconds = 5"):
    if token not in young_wolf_farm_body:
        raise AssertionError(f"starter wolves must stay in the farm-to-spider meadow pocket: {token}")

young_wolf_forward_body = LAYOUT.split('id = "spawn_young_wolf_farm_forward"', 1)[1].split("}", 1)[0]
for token in ("scaleXZ(-235, 8, 535)", "count = 4", "patrolRadius = scaleDistance(62)", "patrolCycleSeconds = 5"):
    if token not in young_wolf_forward_body:
        raise AssertionError(f"forward starter wolves must extend roaming toward Spider Hollow: {token}")

stone_south = LAYOUT.split('id = "spawn_wolf_pack_south"', 1)[1].split("}", 1)[0]
stone_east = LAYOUT.split('id = "spawn_wolf_pack_east"', 1)[1].split("}", 1)[0]
stone_north = LAYOUT.split('id = "spawn_wolf_pack_north"', 1)[1].split("}", 1)[0]
stone_leader = LAYOUT.split('id = "spawn_wolf_pack_leader"', 1)[1].split("}", 1)[0]
for body, count in ((stone_south, 2), (stone_east, 2), (stone_north, 3)):
    if f"count = {count}" not in body or 'socialGroupId = "wolf_pack_stone_circle"' not in body:
        raise AssertionError("Stone Circle pack must contain seven linked ordinary wolves")
if 'socialGroupId = "wolf_pack_stone_circle"' not in stone_leader:
    raise AssertionError("Stone Circle leader must belong to the same eight-member pack")

moonfall_wolf_body = LAYOUT.split('id = "spawn_wolf_pack_moonfall"', 1)[1].split("}", 1)[0]
for token in (
    "scaleXZ(55, 16, 820)",
    "count = 7",
    'zoneId = "zone_moonfall_road"',
    'socialGroupId = "wolf_pack_moonfall"',
    "patrolRadius = scaleDistance(48)",
    "patrolCycleSeconds = 6",
):
    if token not in moonfall_wolf_body:
        raise AssertionError(f"second Moonfall wolf pack must guard the goblin approach: {token}")

moonfall_leader_body = LAYOUT.split('id = "spawn_wolf_pack_moonfall_leader"', 1)[1].split("}", 1)[0]
for token in ('mobId = "mob_wolf_pack_leader"', 'socialGroupId = "wolf_pack_moonfall"', 'zoneId = "zone_moonfall_road"'):
    if token not in moonfall_leader_body:
        raise AssertionError(f"second Moonfall pack leader contract missing: {token}")

for token in ('id = "wolf_pack_howl"', "radius = 50", "callsAllies = true"):
    if token not in ABILITIES:
        raise AssertionError(f"wolf leader howl must call nearby pack members: {token}")

for token in (
    "detectionRadius = 52, aggroRadius = 45, reacquireRadius = 60, leashDistance = 112",
    "chaseSpeed = 15, decisionIntervalSeconds = 0.36",
    "detectionRadius = 60, aggroRadius = 51, reacquireRadius = 69, leashDistance = 135",
):
    if token not in MOBS:
        raise AssertionError(f"wolf mobility/aggro tuning is missing: {token}")

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
for marker_id, group_id in (
    ("spawn_goblin_gate_pair_south", "goblin_gate_pair_south"),
    ("spawn_goblin_gate_pair_north", "goblin_gate_pair_north"),
):
    marker_body = LAYOUT.split(f'id = "{marker_id}"', 1)[1].split("}", 1)[0]
    if "count = 2" not in marker_body or f'socialGroupId = "{group_id}"' not in marker_body:
        raise AssertionError(f"{marker_id} must remain a compact social pair near the camp approach")

shaman_body = LAYOUT.split('id = "spawn_goblin_shaman_camp"', 1)[1].split("}", 1)[0]
warrior_body = LAYOUT.split('id = "spawn_goblin_warrior_camp"', 1)[1].split("}", 1)[0]
for body in (shaman_body, warrior_body):
    if 'socialGroupId = "goblin_courtyard"' not in body:
        raise AssertionError("shaman and his two warriors must remain one social interior group")
if "count = 2" not in warrior_body:
    raise AssertionError("shaman encounter must include two warriors")
if "scaleXZ(250, 62, 1005)" not in shaman_body:
    raise AssertionError("shaman must stay inside the goblin camp with his warrior pair")

for pair_id, group_id in (
    ("spawn_goblin_inner_pair_a_scout", "goblin_inner_pair_a"),
    ("spawn_goblin_inner_pair_a_warrior", "goblin_inner_pair_a"),
    ("spawn_goblin_inner_pair_b_scout", "goblin_inner_pair_b"),
    ("spawn_goblin_inner_pair_b_warrior", "goblin_inner_pair_b"),
):
    body = LAYOUT.split(f'id = "{pair_id}"', 1)[1].split("}", 1)[0]
    if f'socialGroupId = "{group_id}"' not in body:
        raise AssertionError(f"{pair_id} must remain linked to its mixed interior pair")

chief_body = LAYOUT.split('id = "spawn_goblin_chieftain_camp"', 1)[1].split("}", 1)[0]
chief_guard_body = LAYOUT.split('id = "spawn_goblin_chieftain_guard"', 1)[1].split("}", 1)[0]
for body in (chief_body, chief_guard_body):
    if 'socialGroupId = "goblin_chief_group"' not in body:
        raise AssertionError("chieftain and dedicated warrior must remain one social group")

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
    '"TargetHitbox"',
    "hitbox.CanQuery = true",
    '"MobNameplate"',
    "MOB_NAMEPLATE_MAX_DISTANCE = 100",
    'string.format("LV %d · %s"',
    "GLOBAL_MOB_MOVEMENT_MULTIPLIER = 1.2",
    "hitboxVerticalOffset",
):
    if token not in MOB_SERVICE:
        raise AssertionError(f"MobService population contract missing {token}")

for token in (
    "otherRecord.socialGroupId == socialGroupId",
    "requestSocialAssist(record, record.target)",
    "math.max(",
    "definition.socialAssistRadius",
	"MobAIRules.canRequestSocialAssist",
    "patrolDestination",
    "isCampPerimeterPatrol",
    "humanoid:MoveTo(destination)",
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
    "ability.callsAllies",
    "MobService.registerHostileAction",
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

# dev0.2 goblin tuning: wider local social response, stronger aggro and real perimeter roaming.
for token in (
    "detectionRadius = 52, aggroRadius = 46, reacquireRadius = 64, leashDistance = 120",
    "socialAssistRadius = 72",
    "detectionRadius = 60, aggroRadius = 54, reacquireRadius = 72, leashDistance = 125",
    "socialAssistRadius = 78",
):
    if token not in MOBS:
        raise AssertionError(f"dev0.2 goblin aggro/social tuning missing: {token}")

for marker_id in ("spawn_goblin_patrol_south", "spawn_goblin_patrol_east", "spawn_goblin_patrol_north", "spawn_goblin_patrol_west"):
    body = LAYOUT.split(f'id = "{marker_id}"', 1)[1].split("}", 1)[0]
    if "patrolCycleSeconds = 6" not in body:
        raise AssertionError(f"{marker_id} must actively traverse its perimeter patrol")

for token in (
    'displayName = "Гоблин-шаман", level = 6, maxHealth = 240',
    'basicAttackRange = 34, basicAttackDamage = 22, basicAttackDamageType = "Magic"',
    'criticalChance = 0.12, criticalDamageMultiplier = 1.60',
    '"goblin_war_chant", "goblin_spirit_bolt", "goblin_shaman_hex"',
    'displayName = "Гоблин-вожак", level = 7, maxHealth = 600',
    'criticalChance = 0.20, criticalDamageMultiplier = 1.80',
    '"goblin_battle_cry", "goblin_sling_stone", "goblin_heavy_strike", "goblin_cleave"',
    'displayName = "Лунный страж", level = 14, maxHealth = 1200',
):
    if token not in MOBS:
        raise AssertionError(f"dev0.2 difficulty tuning missing: {token}")

for token in (
    'DamageRules.resolve(',
    'definition.criticalChance or 0',
    'definition.criticalDamageMultiplier or CombatConfig.CriticalDamageMultiplier',
    'isCritical = rolled.isCritical',
):
    if token not in MOB_ABILITY_SERVICE:
        raise AssertionError(f"server-authoritative mob critical contract missing: {token}")

print("Mob Content Pass v0.1 + dev0.2 tuning contract: PASS")
