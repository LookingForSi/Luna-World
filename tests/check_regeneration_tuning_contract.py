#!/usr/bin/env python3
"""Static contract for player HP/resource regeneration tuning."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CONFIG = (ROOT / "src/shared/config/CombatConfig.luau").read_text(encoding="utf-8")
SERVICE = (ROOT / "src/server/services/PlayerRegenerationService.luau").read_text(encoding="utf-8")
MAIN = (ROOT / "src/server/main.server.luau").read_text(encoding="utf-8")

for token in (
    "ResourceRegenerationIntervalSeconds = 0.2",
    "HealthRegenerationIntervalSeconds = 0.2",
    "HealthRegenerationDelaySeconds = 5",
    "HealthRegenerationFractionPerSecond = 1 / 150",
    "resourceRegenerationPerSecond = 2.5",
    "resourceRegenerationPerSecond = 3",
    "resourceRegenerationPerSecond = 2",
):
    if token not in CONFIG:
        raise AssertionError(f"regeneration tuning missing: {token}")

for token in (
    'instance.Name == "Health"',
    "humanoid.Health <=",
    "record.lastDamageAt",
    "HealthRegenerationFractionPerSecond",
    "humanoid.MaxHealth",
):
    if token not in SERVICE:
        raise AssertionError(f"health regeneration service contract missing: {token}")

for token in (
    "PlayerRegenerationService.start()",
    "PlayerRegenerationService.stop()",
):
    if token not in MAIN:
        raise AssertionError(f"server regeneration lifecycle missing: {token}")

print("Player regeneration tuning contract: PASS")
