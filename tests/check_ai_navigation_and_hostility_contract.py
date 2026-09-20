#!/usr/bin/env python3
"""Static acceptance contract for mob obstacle navigation, debuff hostility, and combat-log placement."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    candidate = ROOT / path
    if not candidate.exists():
        raise AssertionError(f"missing required file: {path}")
    return candidate.read_text(encoding="utf-8")


def require(path: str, token: str, message: str) -> None:
    if token not in read(path):
        raise AssertionError(message)


AI = "src/server/services/MobAIService.luau"
MOBS = "src/server/services/MobService.luau"
EFFECTS = "src/server/services/CombatEffectService.luau"
LOG = "src/client/ui/CombatLog.luau"

require(AI, "AgentCanJump = false", "mob paths must respect Luna World's no-free-jump rule")
require(AI, "navigationDetour", "mob chase must retain a short obstacle detour instead of recomputing into the same wall")
require(AI, "workspace:Raycast", "mob navigation must detect a blocking low obstacle before walking into it")
require(AI, "chooseObstacleDetour", "mob navigation needs a deterministic lateral detour around blocked direct movement")
require(MOBS, "function MobService.registerHostileAction", "non-damaging hostile effects need a server-owned aggro seam")
require(EFFECTS, "MobService.registerHostileAction(target.entityId, actor)", "movement debuffs such as Snare must provoke the affected mob")
require(LOG, 'root.Position = UDim2.new(0, HudLayout.CornerMargin, 1, -HudLayout.CornerMargin)', "combat log must use the shared bottom-left HUD corner margin")

print("AI navigation, hostile debuff, and combat-log placement contract: PASS")
