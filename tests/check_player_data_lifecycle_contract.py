#!/usr/bin/env python3
"""Static contract for authoritative player profile lifecycle and progression integration."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


DATA = read("src/server/services/PlayerDataService.luau")
PROGRESSION = read("src/server/services/ProgressionService.luau")
COMBAT = read("src/server/services/CombatService.luau")
MAIN = read("src/server/bootstrap/adapters/ExistingServerComponents.luau")
CONFIG = read("src/shared/config/PersistenceConfig.luau")

for token in (
    '"Loading"',
    '"AccountReady"',
    '"CharacterReady"',
    '"Saving"',
    '"Released"',
    '"Error"',
    "ProfileReady",
    "ProfileChanged",
    "PlayerDataService.mutate",
    "AccountSchema.validateCurrent",
    "AutosaveSeconds",
):
    if token not in DATA:
        raise AssertionError(f"PlayerDataService contract missing {token}")

if "UseDataStoreInStudio = false" not in CONFIG:
    raise AssertionError("Studio must stay API-independent until the real DataStore checkpoint")

if "PlayerDataService.start" not in MAIN or "PlayerDataService.stop" not in MAIN:
    raise AssertionError("server bootstrap must own PlayerDataService lifecycle")

for token in (
    "PlayerDataService.getProfileCopy",
    "PlayerDataService.mutate",
    "profile.Level",
    "profile.XP",
):
    if token not in PROGRESSION:
        raise AssertionError(f"ProgressionService must be profile-backed: missing {token}")

for handler in ("onTargetRequest", "onAttackRequest", "onSkillRequest"):
    start = COMBAT.find(f"local function {handler}")
    if start < 0:
        raise AssertionError(f"missing {handler}")
    snippet = COMBAT[start:start + 500]
    if "PlayerDataService.isReady(player)" not in snippet:
        raise AssertionError(f"{handler} must reject gameplay before profile readiness")

print("Player data lifecycle contract: PASS")
