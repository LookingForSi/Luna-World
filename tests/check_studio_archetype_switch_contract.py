#!/usr/bin/env python3
"""Static contract for the Studio-only archetype switcher."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
debug = (ROOT / "src/server/services/StudioDebugService.luau").read_text(encoding="utf-8")
combat = (ROOT / "src/server/services/CombatService.luau").read_text(encoding="utf-8")

if "not RunService:IsStudio()" not in debug:
    raise AssertionError("Studio debug service must remain unavailable outside Studio")
if "CombatService._setArchetypeForStudio" not in debug:
    raise AssertionError("Studio switcher must delegate lifecycle reset to CombatService")
if "function CombatService._setArchetypeForStudio" not in combat:
    raise AssertionError("CombatService must expose the Studio-only archetype reset seam")
if 'assert(RunService:IsStudio()' not in combat:
    raise AssertionError("Studio archetype seam must hard-fail outside Studio")
if "clearPlayerState(player, true)" not in combat:
    raise AssertionError("archetype switch must discard the previous authoritative combat state before respawn")
if "player:SetAttribute(ARCHETYPE_ATTRIBUTE, archetypeId)" not in combat:
    raise AssertionError("new archetype must be written only after old combat state is cleared")

print("Studio archetype switch contract: PASS")
