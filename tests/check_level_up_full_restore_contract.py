#!/usr/bin/env python3
"""Static contract: a real level-up fully restores CP, HP and class resource."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
progression = (ROOT / "src/server/services/ProgressionService.luau").read_text(encoding="utf-8")
combat = (ROOT / "src/server/services/CombatService.luau").read_text(encoding="utf-8")

for token in (
    "local CombatService = require(script.Parent.CombatService)",
    "levelsGained = result.levelsGained",
    "if levelsGained > 0 then",
    "CombatService.restorePlayerVitalsAfterLevelUp(player)",
):
    if token not in progression:
        raise AssertionError(f"level-up trigger contract missing: {token}")

if progression.count("CombatService.restorePlayerVitalsAfterLevelUp(player)") != 2:
    raise AssertionError("level-up refill must be wired for real XP gain and Studio upward level changes only")

for token in (
    "function CombatService.restorePlayerVitalsAfterLevelUp",
    "CombatService.refreshPlayerStats(player)",
    "state.stats.resource = ResourceRules.restore(state.stats.resource, state.stats.resource.maximum)",
    "state.regenerationElapsed = 0",
    "restoreCombatPoints(player)",
    "humanoid.Health = humanoid.MaxHealth",
):
    if token not in combat:
        raise AssertionError(f"full level-up refill contract missing: {token}")

# This feature is a refill, not a combat reset: it must not clear targets,
# cooldowns or active effects just because XP crossed a level boundary.
restore_start = combat.index("function CombatService.restorePlayerVitalsAfterLevelUp")
restore_end = combat.index("\nlocal function getPlayerByCanonicalTargetId", restore_start)
restore_body = combat[restore_start:restore_end]
for forbidden in ("clearPlayerState(", "table.clear(", "clearPlayerEffects("):
    if forbidden in restore_body:
        raise AssertionError(f"level-up refill must not reset combat state: {forbidden}")

print("Level-up full restore contract: PASS")
