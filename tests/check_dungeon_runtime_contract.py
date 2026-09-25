from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text()

transfer = read("src/server/features/dungeon/DungeonTransferService.luau")
admission = read("src/server/features/dungeon/DungeonAdmissionService.luau")
run = read("src/server/features/dungeon/DungeonRunService.luau")
encounter = read("src/server/features/dungeon/DungeonEncounterService.luau")
returned = read("src/server/features/dungeon/DungeonReturnService.luau")
dev = read("src/server/features/dungeon/DevCombinedDungeonAdapter.luau")
party = read("src/server/features/party/PartyService.luau")

assert "PlayerDataService.beginTransfer" in transfer and "MemoryStoreTransferIntentStore" in transfer
assert "setPreClaimValidator" in admission and "IntentRules.validate" in admission
assert "DungeonRejoin" in transfer and "ReservedServerAccessCode" in transfer
assert "Humanoid" in run and "PARTY_WIPE" in run and "Checkpoint" in run
assert "DungeonWorld.inspectBounds" in run and "PLAYER_OUT_OF_BOUNDS" in run
assert "removeConfigured" in encounter and "DungeonResetGeneration" in encounter
assert "DungeonWorld.toWorld" in encounter and "Layout.EncounterPositions" in encounter
assert "BOSS_ENRAGED" in encounter and "GuardianDangerZone" in encounter
assert "DungeonReturn" in returned and "returnInProgress" in returned
assert "restoreTrusted" in party
assert 'assert(RunService:IsStudio()' in dev
assert 'DungeonWorld.start(true)' in dev and 'DungeonWorld.getRoot() == nil' in dev
print("Dungeon M6 runtime integration contract: PASS")
