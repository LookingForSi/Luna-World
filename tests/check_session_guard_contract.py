#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

service = read("src/server/session/SessionGuardService.luau")
store = read("src/server/session/MemoryStoreSessionGuardStore.luau")
rules = read("src/shared/session/SessionGuardRules.luau")
data = read("src/server/services/PlayerDataService.luau")
components = read("src/server/bootstrap/adapters/ExistingServerComponents.luau")
lobby = read("src/server/bootstrap/manifests/LobbyServerManifest.luau")
world = read("src/server/bootstrap/manifests/WorldServerManifest.luau")
dungeon = read("src/server/bootstrap/manifests/DungeonServerManifest.luau")
dev = read("src/server/bootstrap/manifests/DevCombinedServerManifest.luau")
place_transfer = read("src/server/core/transfer/PlaceTransferService.luau")
dungeon_transfer = read("src/server/features/dungeon/DungeonTransferService.luau")
dungeon_return = read("src/server/features/dungeon/DungeonReturnService.luau")

for token in (
    "MemoryStoreService:GetHashMap",
    "UpdateAsync",
    "Rules.canClaim",
    "Rules.isOwner",
):
    assert token in store, f"SessionGuard store missing {token}"

for token in (
    'PlayerDataService.setAdmissionValidator("SessionGuard", Service.admit)',
    "HttpService:GenerateGUID(false)",
    "Rules.readRoutedSessionId",
    "store:claim",
    "store:renew",
    "store:release",
    "player:Kick",
    "attachRoutingPayload",
    "experienceSessionIds",
):
    assert token in service, f"SessionGuard service missing {token}"

assert "admissionValidators" in data and "setAdmissionValidator" in data
assert data.index("preClaimValidator(player)") < data.index("for validatorName, validator in admissionValidators")

for manifest in (lobby, world, dungeon):
    assert "Components.sessionGuard()" in manifest
    assert manifest.index("Components.sessionGuard()") < manifest.index("Components.playerData()")
assert "Components.sessionGuard()" not in dev

assert "sessionGuard = SessionGuardService" in components
assert "self.sessionGuard.attachRoutingPayload" in place_transfer
assert "SessionGuardService.attachRoutingPayload" in dungeon_transfer
assert "SessionGuardService.attachRoutingPayload" in dungeon_return

assert "experienceSessionIds" in rules
assert "AuthoritativeStateForbidden" in read("src/shared/core/transfer/TransferIntentRules.luau")

print("SessionGuard contract: PASS")
