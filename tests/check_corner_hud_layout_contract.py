#!/usr/bin/env python3
"""Static contract for the shared corner HUD grid and four-row player status panel."""

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


LAYOUT = "src/client/ui/HudLayout.luau"
HUD = "src/client/ui/CombatHud.luau"
ACTIONS = "src/client/ui/ActionBar.luau"
LOG = "src/client/ui/CombatLog.luau"
CONFIG = "src/shared/config/CombatConfig.luau"
PROGRESSION_CONFIG = "src/shared/config/ProgressionConfig.luau"
CLIENT_MAIN = "src/client/main.client.luau"
COMBAT = "src/server/services/CombatService.luau"

require(LAYOUT, "HudLayout.CornerMargin = 24", "all corner panels must share one visible safe margin")
require(LAYOUT, "function HudLayout.applyPanelStyle", "corner panels must share one visual panel style")

require(HUD, "UDim2.new(1, -HudLayout.CornerMargin, 0, HudLayout.CornerMargin)", "player status must use the shared top-right anchor")
require(HUD, "gui.IgnoreGuiInset = true", "top HUD must measure its margin from the physical viewport edge")
require(ACTIONS, "UDim2.new(1, -HudLayout.CornerMargin, 1, -HudLayout.CornerMargin)", "action panel must use the shared bottom-right anchor")
require(LOG, "UDim2.new(0, HudLayout.CornerMargin, 1, -HudLayout.CornerMargin)", "combat log must use the shared bottom-left anchor")

for token in ('"CombatPoints"', '"PlayerHealth"', '"PlayerResource"', '"LevelXP"'):
    require(HUD, token, f"four-row player status is missing row {token}")
for token in ('"CombatPointsFill"', '"PlayerHealthFill"', '"PlayerResourceFill"', '"LevelXPFill"'):
    require(HUD, token, f"four-row player status is missing fill {token}")

require(HUD, '"LevelBadge"', "player status must include a dedicated level badge")
require(HUD, '"LevelNumber"', "level badge must render the current level number")
require(HUD, "ProgressionRules.requiredXP(level)", "XP bar must use the current level threshold")
require(HUD, "formatStatusNumber(currentValue)", "status rows must expose exact current values")
require(CLIENT_MAIN, "SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)", "stock Roblox health bar must be hidden")

require(CONFIG, 'CombatPointsCurrentAttribute = "CombatPointsCurrent"', "CP needs a distinct replicated current-value attribute")
require(CONFIG, 'CombatPointsMaximumAttribute = "CombatPointsMaximum"', "CP needs a distinct replicated maximum attribute")
require(COMBAT, "ensureCombatPoints(player)", "CP must be initialized by the server")
require(COMBAT, "restoreCombatPoints(player)", "CP must be restored on respawn")

# PvE mob damage continues to damage Humanoid HP directly; CP is not consumed by the PvE path.
mob_damage_block = read(COMBAT)
if "CombatPointsCurrentAttribute" in mob_damage_block[mob_damage_block.find("function CombatService.requestMobBasicAttack"):mob_damage_block.find("function CombatService.handlePlayerDeath")]:
    raise AssertionError("PvE mob attacks must not consume PvP-only CP")

print("Corner HUD and PvP CP contract: PASS")
