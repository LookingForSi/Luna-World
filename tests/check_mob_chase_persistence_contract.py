#!/usr/bin/env python3
"""Static contract for target-separation chase disengage and bounded return recovery."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ai = (ROOT / "src/server/services/MobAIService.luau").read_text(encoding="utf-8")
rules = (ROOT / "src/shared/combat/MobAIRules.luau").read_text(encoding="utf-8")
defs = (ROOT / "src/shared/definitions/MobDefinitions.luau").read_text(encoding="utf-8")

for token in (
    "local RETURN_TELEPORT_SECONDS = 150",
    "local targetDistance = if targetRoot ~= nil then (targetRoot.Position - root.Position).Magnitude else math.huge",
    "targetDistance > definition.leashDistance",
    "beyondLeash = targetBeyondLeash",
    "now - record.returnStartedAt >= RETURN_TELEPORT_SECONDS",
    "record.model:PivotTo(CFrame.new(record.home))",
    "record.hostileAttacker = attacker",
    "record.target = attacker",
):
    if token not in ai:
        raise AssertionError(f"target-separation chase contract missing: {token}")

# Disengage must be based on the current player↔mob gap. Distance from the
# original spawn is only used to detect arrival home during Return.
if "BLIND_RETURN_DISTANCE" in ai or "distanceFromHome >" in ai:
    raise AssertionError("mob chase must not disengage based on distance from spawn/home")

if 'if context.hostileAttacker then return "Aggro" end' not in rules:
    raise AssertionError("fresh hostile damage must break a return state")

for token in (
    "detectionRadius = 90, aggroRadius = 82, reacquireRadius = 120, leashDistance = 120",
    "detectionRadius = 94, aggroRadius = 86, reacquireRadius = 124, leashDistance = 125",
    "detectionRadius = 100, aggroRadius = 92, reacquireRadius = 132, leashDistance = 125",
    "detectionRadius = 110, aggroRadius = 100, reacquireRadius = 145, leashDistance = 140",
):
    if token not in defs:
        raise AssertionError(f"goblin chase tuning missing: {token}")

print("Target-separation mob chase + goblin aggro contract: PASS")
