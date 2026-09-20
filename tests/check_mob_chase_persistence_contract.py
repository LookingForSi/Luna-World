#!/usr/bin/env python3
"""Static contract for persistent engaged-mob chase and bounded return recovery."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ai = (ROOT / "src/server/services/MobAIService.luau").read_text(encoding="utf-8")
rules = (ROOT / "src/shared/combat/MobAIRules.luau").read_text(encoding="utf-8")
defs = (ROOT / "src/shared/definitions/MobDefinitions.luau").read_text(encoding="utf-8")

for token in (
    "local BLIND_RETURN_DISTANCE = 750",
    "local RETURN_TELEPORT_SECONDS = 150",
    "local function hasLineOfSight",
    "nearestPlayer(root.Position, definition.aggroRadius)",
    "not targetVisible and distanceFromHome > BLIND_RETURN_DISTANCE",
    "now - record.returnStartedAt >= RETURN_TELEPORT_SECONDS",
    "record.model:PivotTo(CFrame.new(record.home))",
    "record.hostileAttacker = attacker",
    "record.target = attacker",
):
    if token not in ai:
        raise AssertionError(f"persistent chase contract missing: {token}")

if "if context.hostileAttacker then return \"Aggro\" end" not in rules:
    raise AssertionError("fresh hostile damage must break a return state")

for token in (
    "detectionRadius = 90, aggroRadius = 82, reacquireRadius = 120",
    "detectionRadius = 94, aggroRadius = 86, reacquireRadius = 124",
    "detectionRadius = 100, aggroRadius = 92, reacquireRadius = 132",
    "detectionRadius = 110, aggroRadius = 100, reacquireRadius = 145",
):
    if token not in defs:
        raise AssertionError(f"goblin aggro tuning missing: {token}")

print("Persistent mob chase + goblin aggro contract: PASS")
