#!/usr/bin/env python3
"""Static contract for the scrollable player log and progression entries."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOG = (ROOT / "src/client/ui/CombatLog.luau").read_text(encoding="utf-8")

required = {
    'Instance.new("ScrollingFrame")': "player log must use a ScrollingFrame",
    "AutomaticCanvasSize = Enum.AutomaticSize.Y": "player log canvas must grow with history",
    "ScrollingDirection = Enum.ScrollingDirection.Y": "player log must scroll vertically",
    "MAX_ENTRIES = 200": "player log must retain meaningful post-combat history",
    '"ЛОГ  ▲"': "expanded log title must be renamed to ЛОГ",
    '"ЛОГ  ▼"': "collapsed log title must be renamed to ЛОГ",
    "ProgressionConfig.LevelAttribute": "player log must observe authoritative level changes",
    '"★ Получен уровень %d."': "level-up entry text is missing",
    "isNearBottom": "log must distinguish live-follow from manual history review",
    "scrollToBottom": "log must auto-follow only while the user is at the bottom",
}

for token, message in required.items():
    if token not in LOG:
        raise AssertionError(message)

print("Scrollable player log contract: PASS")
