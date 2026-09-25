#!/usr/bin/env python3
"""Regression contract for atomic Selene admission and prompt-bound confirmation."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str: return (ROOT / path).read_text(encoding="utf-8")

run = read("src/server/features/dungeon/DungeonRunService.luau")
transfer = read("src/server/features/dungeon/DungeonTransferService.luau")
client = read("src/client/features/dungeon/DungeonController.luau")
dev = read("src/server/features/dungeon/DevCombinedDungeonAdapter.luau")
recovery = read("src/server/world/TraversalRecovery.luau")
config = read("src/shared/dungeon/DungeonConfig.luau")

# Admission cannot expose the participant to ACTIVE/OOB until a real, stable placement.
placed = run.index('log("DUNGEON_ADMISSION_PLACED"')
active = run.index('transition("ACTIVE")', placed)
assert placed < active
assert 'RunService.Heartbeat:Wait()' in run
assert 'DungeonWorld.inspectBounds' in run
assert 'nearCheckpoint' in run
assert 'admissionPending[player] or not within' in run
assert run.index('characterProtected[player] = false', run.index('local nearCheckpoint')) < placed
assert 'transition("FAILED")' in run and 'broadcast("RETRY_AVAILABLE"' in run
assert 'log("DUNGEON_ADMISSION_REJECTED"' in run

# DevCombined must suspend the Moonfall recovery owner that used to undo PivotTo.
assert 'TraversalRecovery.setPlayerExcluded(player, true)' in dev
assert 'TraversalRecovery.setPlayerExcluded(player, false)' in dev
assert 'if excluded[player] then' in recovery
assert dev.index('setPlayerExcluded(player, true)') < dev.index('DungeonRun.admit(player, contract)')

# A server-issued token is required, single-use, and expires independently of UI speed.
assert 'ConfirmationTtlSeconds=30' in config
assert 'confirmationToken=token' in transfer
assert 'confirmations[leader]=nil' in transfer
assert 'confirmation.token~=confirmationToken' in transfer
assert 'os.clock()>confirmation.expiresAt' in transfer
assert 'payload.confirmationToken' in transfer and 'confirmationToken=confirmationToken' in client
assert 'ENTRY_CONFIRMATION' in transfer

# A failed local admission closes the same run; active=false permits a retry rather than a second live run.
assert 'if active then return end' in dev
assert 'active = false' in dev
assert 'close()' in dev
print("Dungeon atomic admission and confirmation contract: PASS")
