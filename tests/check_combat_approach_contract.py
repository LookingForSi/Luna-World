#!/usr/bin/env python3
"""Static contract for click-to-range combat and retaliation targeting."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

combat = (ROOT / "src/server/features/combat/CombatCoordinator.luau").read_text(encoding="utf-8")
mob_abilities = (ROOT / "src/server/services/MobAbilityService.luau").read_text(encoding="utf-8")
target = (ROOT / "src/client/controllers/TargetController.luau").read_text(encoding="utf-8")
config = (ROOT / "src/shared/config/CombatConfig.luau").read_text(encoding="utf-8")
log_rules = (ROOT / "src/shared/combat/ClientCombatLogRules.luau").read_text(encoding="utf-8")
north = (ROOT / "tools/worldgen/moonfall/NorthernZonesBlockout.luau").read_text(encoding="utf-8")

for token in (
    'type PendingApproach = {',
    'kind: "Attack" | "Skill"',
    'pendingApproachesByPlayer',
    'beginApproach(player, targetId, "Attack", nil, BasicAttackService.getDefinition(state).range)',
    'beginApproach(player, selectedTargetId, "Skill", definition.id, definition.range)',
    'distance <= pending.range + CombatConfig.RangeTolerance',
    'humanoid:MoveTo(targetRoot.Position)',
    'processApproaches(now)',
    'clearApproach(player, true)',
):
    if token not in combat:
        raise AssertionError(f"missing approach-to-range behavior: {token}")

for token in (
    'ApproachMoveRefreshSeconds = 0.15',
    'TargetSelectionRange = 100',
):
    if token not in config:
        raise AssertionError(f"missing combat approach config: {token}")

if 'OutOfRange = "цель слишком далеко"' not in log_rules:
    raise AssertionError("out-of-range feedback must be readable")

if 'Enum.UserInputType.MouseButton2' not in target or 'TargetController.clearTarget()' not in target:
    raise AssertionError("right mouse must clear target on desktop")

if 'CombatCoordinator.selectAttackerIfNoTarget(target, mob)' not in mob_abilities:
    raise AssertionError("incoming hostile mob damage must auto-select the attacker")

for token in (
    'function CombatCoordinator.selectAttackerIfNoTarget',
    'if targetsByPlayer[player] ~= nil',
    'onTargetRequest(player, entityId)',
):
    if token not in combat:
        raise AssertionError(f"attacker auto-target authority missing: {token}")

for required in (
    "createCampPalisadeLine",
    "fenceSegments",
    '"CampPalisade%02d"',
    "gateHalfWidth = 32",
    "PalisadeCollision = true",
):
    if required not in north:
        raise AssertionError(f"accepted collision-sealed goblin palisade contract missing: {required}")

print("Click-to-range combat + retaliation targeting contract: PASS")
