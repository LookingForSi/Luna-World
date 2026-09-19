#!/usr/bin/env python3
"""Static contract for visible AUTO attack input bindings."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUT = (ROOT / "src/client/controllers/CombatInputController.luau").read_text(encoding="utf-8")
BAR = (ROOT / "src/client/ui/ActionBar.luau").read_text(encoding="utf-8")

for token in ('Enum.KeyCode.G', 'Enum.KeyCode.ButtonL2'):
    if token not in INPUT:
        raise AssertionError(f"AUTO attack input binding is missing {token}")

if '"G"' not in BAR or '"L2"' not in BAR:
    raise AssertionError("AUTO button must expose its keyboard/gamepad binding")

print("AUTO attack binding contract: PASS")
